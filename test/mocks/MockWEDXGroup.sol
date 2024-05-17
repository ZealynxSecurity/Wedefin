// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../contracts/IWEDXInterfaces.sol";

contract MockWEDXGroup is IWEDXGroup {
    address private _ownerAddress;
    address private _assetManagerAddress;

    constructor(address managerAddress) {
        _ownerAddress = msg.sender;
        _assetManagerAddress = managerAddress;
    }

    function owner() external view override returns (address) {
        return _ownerAddress;
    }

    function getAssetManagerAddress() external view override returns (address) {
        return _assetManagerAddress;
    }

    // Implementaciones vacías para las funciones faltantes
    function getDeployerProAddress() external view override returns (address) {
        return address(0);
    }

    function getLenderContractAddress() external view override returns (address) {
        return address(0);
    }

    function getRankAddress() external view override returns (address) {
        return address(0);
    }

    function getSwapContractAddress() external view override returns (address) {
        return address(0);
    }

    function getTreasuryAddress() external view override returns (address) {
        return address(0);
    }
}
