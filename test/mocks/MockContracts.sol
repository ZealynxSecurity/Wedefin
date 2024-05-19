// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockAssetManager {
    function depositWithdrawFee() external pure returns (uint256) {
        return 1; // Mock fee value
    }
}

contract MockTreasury {
    function depositGeneralFee() external payable {}
}

contract MockWEDXGroup {
    address public assetManager;
    address public treasury;
    address public swapContract;

    constructor(address _assetManager, address _treasury, address _swapContract) {
        assetManager = _assetManager;
        treasury = _treasury;
        swapContract = _swapContract;
    }

    function getAssetManagerAddress() external view returns (address) {
        return assetManager;
    }

    function getTreasuryAddress() external view returns (address) {
        return treasury;
    }

    function getSwapContractAddress() external view returns (address) {
        return swapContract;
    }
}

contract MockWETH9 {
    function deposit() external payable {}
    function withdraw(uint256) external {}
}
