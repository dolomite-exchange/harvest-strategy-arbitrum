pragma solidity ^0.5.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract IRenWbtcPool is IERC20 {

    function add_liquidity(uint[2] calldata amounts, uint min_mint_amount) external;

    function coins(uint i) external view returns (address);
}
