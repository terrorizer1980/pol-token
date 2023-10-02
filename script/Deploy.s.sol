// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";

import {ProxyAdmin, TransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {PolygonEcosystemToken} from "../src/PolygonEcosystemToken.sol";
import {DefaultEmissionManager} from "../src/DefaultEmissionManager.sol";
import {PolygonMigration} from "../src/PolygonMigration.sol";

contract Deploy is Script {
    uint256 public deployerPrivateKey;

    constructor() {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function run(
        address matic,
        address governance,
        address treasury,
        address stakeManager,
        address permit2revoker
    ) public {
        vm.startBroadcast(deployerPrivateKey);

        ProxyAdmin admin = new ProxyAdmin();
        admin.transferOwnership(governance);

        address migrationImplementation = address(new PolygonMigration(matic));

        address migrationProxy = address(
            new TransparentUpgradeableProxy(
                migrationImplementation,
                address(admin),
                abi.encodeWithSelector(PolygonMigration.initialize.selector)
            )
        );

        address emissionManagerImplementation = address(
            new DefaultEmissionManager(migrationProxy, stakeManager, treasury)
        );
        address emissionManagerProxy = address(
            new TransparentUpgradeableProxy(address(emissionManagerImplementation), address(admin), "")
        );

        PolygonEcosystemToken polygonToken = new PolygonEcosystemToken(
            migrationProxy,
            emissionManagerProxy,
            governance,
            permit2revoker
        );

        DefaultEmissionManager(emissionManagerProxy).initialize(address(polygonToken), governance);

        PolygonMigration(migrationProxy).setPolygonToken(address(polygonToken));

        PolygonMigration(migrationProxy).transferOwnership(governance); // governance needs to accept the ownership transfer

        vm.stopBroadcast();
    }
}
