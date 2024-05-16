// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "contracts/WEDXManager.sol";


contract WEDXManagerTest is Test {


    WEDXManager wexmanager;
    function setUp() public {
        wexmanager = new WEDXManager();

    }

    // function test_prove() public {
    //     console.log("HOLA");
    //     vm.assume (wexmanager.rankingList.length =! 0);

    //    wexmanager.setFinalWeights();
    // }

}