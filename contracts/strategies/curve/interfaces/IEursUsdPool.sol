pragma solidity ^0.5.4;


interface IEursUsdPool {

    function add_liquidity(uint[2] calldata amounts, uint min_mint_amount) external;

    function coins(uint i) external view returns (address);
}
