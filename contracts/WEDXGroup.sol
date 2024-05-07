// SPDX-License-Identifier: MIT
// WEDXGroup is a contract to store all the other contract addresses
// It will make the whole project more modular and upgradeable
// Ownership of the this contract is passed to the other smart contracts of WEDX group
// Once a DAO is implemented, the DAO would be the owner
pragma solidity ^0.8.20;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract WEDXGroup is Ownable {

    address private _treasuryContractAddress;
    address private _deployerProAddress;
    address private _deployerIndexAddress;
    address private _assetManagerAddress;
    address private _rankAddress;
    address private _swapContractAddress;
    address private _lenderContractAddress;

    constructor(address initialOwner) Ownable(initialOwner) {}

    function getTreasuryAddress() public view returns (address) {
        return _treasuryContractAddress;
    }

    function getDeployerProAddress() public view returns (address) {
        return _deployerProAddress;
    }

    function getDeployerIndexAddress() public view returns (address) {
        return _deployerIndexAddress;
    }

    function getAssetManagerAddress() public view returns (address) {
        return _assetManagerAddress;
    }

    function getRankAddress() public view returns (address) {
        return _rankAddress;
    }

    function getSwapContractAddress() public view returns (address) {
        return _swapContractAddress;
    }

    function getLenderContractAddress() public view returns (address) {
        return _lenderContractAddress;
    }

    function changeTreasuryAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _treasuryContractAddress = newAddress;
    }

    function changeDeployerProAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _deployerProAddress = newAddress;
    }

    function changeDeployerIndexAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _deployerIndexAddress = newAddress;
    }

    function changeManagerAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _assetManagerAddress = newAddress;
    }

    function changeRankAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _rankAddress = newAddress;
    }

    function changeSwapContractAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _swapContractAddress = newAddress;
    }

    function changeLenderContractAddress(address newAddress) public onlyOwner {
        require( newAddress != address(0), "Invalid address" );
        _lenderContractAddress = newAddress;
    }

}