// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "../../contracts/IWEDXInterfaces.sol";

contract MockWEDXManager is IWEDXManager {
    mapping(address => uint256) private _traderScores;
    address[] private _rankingList;
    address private _rebalanceActor;
    uint256 private _rebalanceActorFee;
    uint256 private _totalRankSum;

    function setTraderScore(address trader, uint256 score) external {
        _traderScores[trader] = score;
        _rankingList.push(trader);
        _totalRankSum += score;
    }

    function getTraderScore(address trader) external view override returns (uint256) {
        return _traderScores[trader];
    }

    function getRankingList() external view override returns (address[] memory) {
        return _rankingList;    }

    function rebalanceActor() external view override returns (address) {
        return _rebalanceActor;
    }

    function setRebalanceActor(address actor) external {
        _rebalanceActor = actor;
    }

    function rebalanceActorFee() external view override returns (uint256) {
        return _rebalanceActorFee;
    }

    function setRebalanceActorFee(uint256 fee) external {
        _rebalanceActorFee = fee;
    }

    function totalRankSum() external view override returns (uint256) {
        return _totalRankSum;
    }

    // Implementaciones vacías para las funciones faltantes
    function computeRanking(address) external override {
        // Implementación vacía para evitar errores de compilación
    }

    function depositWithdrawFee() external view override returns (uint256) {
        return 0;
    }

    function getFinalPortfolio() external view override returns (address[] memory, uint256[] memory) {
        address[] memory emptyAddresses;
        uint256[] memory emptyAmounts;
        return (emptyAddresses, emptyAmounts);
    }

    function minPercIndexAllowance() external view override returns (uint256) {
        return 0;
    }

    function rewardsFee() external view override returns (uint256) {
        return 0;
    }

    function transactionsFee() external view override returns (uint256) {
        return 0;
    }

    function updateTraderData(address, uint256[] memory, address[] memory) external override {
        // Implementación vacía para evitar errores de compilación
    }
}
