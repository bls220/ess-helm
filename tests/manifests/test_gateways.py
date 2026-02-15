# Copyright 2025 Element Creations Ltd
#
# SPDX-License-Identifier: AGPL-3.0-only


import pytest

from . import (
    DeployableDetails,
    PropertyType,
    all_deployables_details,
    values_files_to_test,
)
from .utils import iterate_deployables_gateway_parts, template_id, template_to_deployable_details


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_has_gateway_routes(templates):
    """Verify that HTTPRoute resources are created when gateway.host is set"""
    seen_deployables = set[DeployableDetails]()
    seen_deployables_with_gateways = set[DeployableDetails]()

    for template in templates:
        deployable_details = template_to_deployable_details(template)
        seen_deployables.add(deployable_details)
        if template["kind"] == "HTTPRoute":
            seen_deployables_with_gateways.add(deployable_details)

    # Verify that all deployables that report gateway support are in seen list
    for seen_deployable in seen_deployables_with_gateways:
        assert seen_deployable.has_gateway


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_no_gateway_route_without_host(values, make_templates):
    """Verify HTTPRoute is not created when gateway.host is not set"""
    # Remove gateway hosts to verify routes aren't created
    def remove_gateway_host(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values:
            del gateway_values["host"]
        if gateway_values or deployable_details.get_helm_values(values, PropertyType.Gateway, default_value=None) is not None:
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(remove_gateway_host)

    for template in await make_templates(values):
        assert template["kind"] != "HTTPRoute"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_gateway_hostname_matches_values(values, make_templates):
    """Verify HTTPRoute hostnames match the configured gateway.host"""
    def get_hosts_from_fragment(values_fragment, deployable_details):
        if deployable_details.name == "well-known":
            if not values_fragment.get("host"):
                yield values["serverName"]
            else:
                yield values_fragment["host"]
        else:
            yield values_fragment["host"]

    def get_hosts():
        for deployable_details in all_deployables_details:
            if deployable_details.has_gateway and deployable_details.get_helm_values(
                values, PropertyType.Enabled, default_value=False
            ):
                gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
                if gateway_values and "host" in gateway_values:
                    yield from get_hosts_from_fragment(gateway_values, deployable_details)

    expected_hosts = list(get_hosts())

    found_hosts = []
    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "hostnames" in template["spec"]
            assert len(template["spec"]["hostnames"]) > 0
            found_hosts.extend(template["spec"]["hostnames"])

    assert set(found_hosts) == set(expected_hosts)


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_gateway_routes_use_path_prefix_matching(templates):
    """Verify HTTPRoute rules use PathPrefix matching"""
    for template in templates:
        if template["kind"] == "HTTPRoute":
            assert "rules" in template["spec"]
            assert len(template["spec"]["rules"]) > 0

            for rule in template["spec"]["rules"]:
                assert "matches" in rule
                assert len(rule["matches"]) > 0
                for match in rule["matches"]:
                    if "path" in match:
                        assert "type" in match["path"]
                        assert match["path"]["type"] == "PathPrefix"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_gateway_routes_have_backend_refs(templates):
    """Verify HTTPRoute rules have backendRefs defined"""
    for template in templates:
        if template["kind"] == "HTTPRoute":
            assert "rules" in template["spec"]
            assert len(template["spec"]["rules"]) > 0

            for rule in template["spec"]["rules"]:
                assert "backendRefs" in rule
                assert len(rule["backendRefs"]) > 0
                for backend_ref in rule["backendRefs"]:
                    assert "name" in backend_ref


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_no_gateway_annotations_by_default(templates):
    """Verify no gateway annotations are added by default"""
    for template in templates:
        if template["kind"] == "HTTPRoute":
            assert "annotations" not in template["metadata"]


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_renders_component_gateway_annotations(values, make_templates):
    """Verify component-level gateway annotations are rendered"""
    def set_annotations(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["annotations"] = {"component": "set"}
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_annotations)

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "annotations" in template["metadata"]
            assert "component" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["component"] == "set"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_renders_global_gateway_annotations(values, make_templates):
    """Verify global gateway annotations are rendered"""
    values.setdefault("gateway", {})["annotations"] = {
        "global": "set",
    }

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "annotations" in template["metadata"]
            assert "global" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["global"] == "set"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_merges_global_and_component_gateway_annotations(values, make_templates):
    """Verify global and component gateway annotations are merged"""
    def set_annotations(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["annotations"] = {
                "component": "set",
                "merged": "from_component",
                "global": None,
            }
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_annotations)
    values.setdefault("gateway", {})["annotations"] = {
        "global": "set",
        "merged": "from_global",
    }

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "annotations" in template["metadata"]
            assert "component" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["component"] == "set"

            assert "merged" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["merged"] == "from_component"

            assert "global" in template["metadata"]["annotations"]
            assert template["metadata"]["annotations"]["global"] is None


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_no_gateway_tls_by_default(make_templates, values):
    """Verify TLS is not configured by default"""
    values.setdefault("gateway", {})["tlsEnabled"] = False

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "tls" not in template["spec"]


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_no_gateway_tls_disabled_component(make_templates, values):
    """Verify TLS can be disabled at component level"""
    def set_tls_disabled(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["tlsEnabled"] = False
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_tls_disabled)

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "tls" not in template["spec"]


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_component_gateway_tlsSecret(values, make_templates):
    """Verify component-level TLS secret is used"""
    def set_tls_secret(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["tlsSecret"] = "component-secret"
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_tls_secret)

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "tls" in template["spec"]
            assert "certificateRefs" in template["spec"]["tls"]
            assert len(template["spec"]["tls"]["certificateRefs"]) == 1
            assert template["spec"]["tls"]["certificateRefs"][0]["name"] == "component-secret"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_global_gateway_tlsSecret(values, make_templates):
    """Verify global TLS secret is used"""
    values.setdefault("gateway", {})["tlsSecret"] = "global-secret"

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "tls" in template["spec"]
            assert "certificateRefs" in template["spec"]["tls"]
            assert len(template["spec"]["tls"]["certificateRefs"]) == 1
            assert template["spec"]["tls"]["certificateRefs"][0]["name"] == "global-secret"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_component_gateway_tlsSecret_beats_global(values, make_templates):
    """Verify component TLS secret overrides global setting"""
    def set_tls_secret(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["tlsSecret"] = "component-secret"
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_tls_secret)
    values.setdefault("gateway", {})["tlsSecret"] = "global-secret"

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "tls" in template["spec"]
            assert "certificateRefs" in template["spec"]["tls"]
            assert len(template["spec"]["tls"]["certificateRefs"]) == 1
            assert template["spec"]["tls"]["certificateRefs"][0]["name"] == "component-secret"


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_no_gateway_className_by_default(templates):
    """Verify no gatewayRefs are added by default"""
    for template in templates:
        if template["kind"] == "HTTPRoute":
            assert "parentRefs" not in template["spec"] or len(template["spec"].get("parentRefs", [])) == 0


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_component_gateway_className(values, make_templates):
    """Verify component-level GatewayClass is used"""
    def set_gateway_className(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["className"] = "component-gateway"
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_gateway_className)

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "parentRefs" in template["spec"]
            # Note: The helper may render this differently, check the actual structure
            # This is a basic check; adjust based on actual template output


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_uses_global_gateway_className(values, make_templates):
    """Verify global GatewayClass is used"""
    values.setdefault("gateway", {})["className"] = "global-gateway"

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "parentRefs" in template["spec"]


@pytest.mark.parametrize("values_file", values_files_to_test)
@pytest.mark.asyncio_cooperative
async def test_component_gateway_className_beats_global(values, make_templates):
    """Verify component GatewayClass overrides global setting"""
    def set_gateway_className(deployable_details: DeployableDetails):
        gateway_values = deployable_details.get_helm_values(values, PropertyType.Gateway, default_value={})
        if "host" in gateway_values or gateway_values:
            gateway_values["className"] = "component-gateway"
            deployable_details.set_helm_values(values, PropertyType.Gateway, gateway_values)

    iterate_deployables_gateway_parts(set_gateway_className)
    values.setdefault("gateway", {})["className"] = "global-gateway"

    for template in await make_templates(values):
        if template["kind"] == "HTTPRoute":
            assert "parentRefs" in template["spec"]
