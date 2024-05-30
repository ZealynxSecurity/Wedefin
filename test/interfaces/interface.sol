// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// interface IERC20 {
//     function totalSupply() external view returns (uint256);
//     function balanceOf(address account) external view returns (uint256);
//     function transfer(address recipient, uint256 amount)
//         external
//         returns (bool);
//     function allowance(address owner, address spender)
//         external
//         view
//         returns (uint256);
//     function approve(address spender, uint256 amount) external returns (bool);
//     function transferFrom(address sender, address recipient, uint256 amount)
//         external
//         returns (bool);
// }

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
}