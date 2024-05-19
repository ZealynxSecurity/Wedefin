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
    address public lenderContract;

    constructor(address _assetManager, address _treasury, address _swapContract, address _lenderContract) {
        assetManager = _assetManager;
        treasury = _treasury;
        swapContract = _swapContract;
        lenderContract = _lenderContract;
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

    function getLenderContractAddress() external view returns (address) {
        return lenderContract;
    }
}

contract MockWETH9 {
    function deposit() external payable {}
    function withdraw(uint256) external {}
}

contract MockLender {
    function isLoanPossible(address) external pure returns (bool) {
        return true; // Mock response
    }

    function getTokenBalance(address, address) external pure returns (uint256) {
        return 1000; // Mock balance
    }

    function lendToken(address, uint256) external {}
    function collectToken(address, uint256) external {}
}
