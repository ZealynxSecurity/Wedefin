// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
pragma abicoder v2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IWEDXInterfaces.sol";
import "./WEDXConstants.sol";
import "./library/distroMath.sol";
import {console} from "forge-std/Test.sol";


contract WEDXTreasury is ERC20, WEDXConstants {
    address private _wedxGroupAddr;

    constructor(address wedxGroupAddress) ERC20("WeDeFin Treasury", "WEDT") {
        _wedxGroupAddr = wedxGroupAddress; //@audit => modify 
    }

    function depositGeneralFee() public payable {
        _mint(IWEDXGroup(_wedxGroupAddr).owner(), msg.value);
    }

    function depositRewardFee() public payable {
        address[] memory addresses = IWEDXManager(IWEDXGroup(_wedxGroupAddr).getAssetManagerAddress()).getRankingList();
        uint256 totalRankSum = IWEDXManager(IWEDXGroup(_wedxGroupAddr).getAssetManagerAddress()).totalRankSum();
        address actorAddress = IWEDXManager(IWEDXGroup(_wedxGroupAddr).getAssetManagerAddress()).rebalanceActor();
        uint256 actorFee = IWEDXManager(IWEDXGroup(_wedxGroupAddr).getAssetManagerAddress()).rebalanceActorFee();

        uint256 newAmount = msg.value;
        if (actorFee > 0 && actorAddress != address(0)) {
            _mint(actorAddress, newAmount * actorFee / distroMath.distroNorm);
            newAmount -= newAmount * actorFee / distroMath.distroNorm;
        }

        uint256 totalAmount = 0;
        if (totalRankSum > 0) {
            for (uint i = 0; i < addresses.length; i++) {
                uint256 rank = IWEDXManager(IWEDXGroup(_wedxGroupAddr).getAssetManagerAddress()).getTraderScore(addresses[i]);
                if (rank > 0) {
                    uint payAmount = (newAmount * rank) / totalRankSum;
                    _mint(addresses[i], payAmount);
                    totalAmount += payAmount;
                }
            }
        }
        if (totalAmount < newAmount) {
            _mint(IWEDXGroup(_wedxGroupAddr).owner(), newAmount - totalAmount);
        }
    }

    function redeem(uint256 amount) public returns (uint256) {
        require( balanceOf(msg.sender) >= amount, "Insufficient balance" );
        address payable sender = payable(msg.sender);
        (bool success, ) = sender.call{value: amount}("");
        require(success, "Withdrawal failed");
        _burn( msg.sender, amount );
        console.log("ESTOY DESPUES DE BURN");
        return amount;
    }
    receive() external payable {
        _mint(IWEDXGroup(_wedxGroupAddr).owner(), msg.value);
    }
}
