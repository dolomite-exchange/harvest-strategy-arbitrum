pragma solidity ^0.5.16;

interface IGauge {
    function deposit(uint) external;
    function balanceOf(address) external view returns (uint);
    function withdraw(uint) external;
    function user_checkpoint(address) external;
}
