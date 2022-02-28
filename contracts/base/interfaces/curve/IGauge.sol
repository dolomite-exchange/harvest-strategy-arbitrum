pragma solidity ^0.5.16;


interface IGauge {

    function lp_token() external view returns (address);

    function balanceOf(address user) external view returns (uint);

    function deposit(uint value) external;

    function withdraw(uint value) external;

    function claim_rewards() external;
}
