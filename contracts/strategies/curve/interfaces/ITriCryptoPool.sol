pragma solidity ^0.5.4;


interface ITriCryptoPool {

    function add_liquidity(uint[3] calldata amounts, uint min_mint_amount) external;

    function coins(uint i) external view returns (address);
}
