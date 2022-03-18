// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;


interface IWETH {

    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function approve(address spender, uint amount) external returns (bool);

    function withdraw(uint) external;

    function balanceOf(address user) external view returns (uint);
}
