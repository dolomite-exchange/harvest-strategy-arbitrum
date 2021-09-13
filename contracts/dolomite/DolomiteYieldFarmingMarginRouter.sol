pragma solidity ^0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract DolomiteYieldFarmingMarginRouter {
    using SafeERC20 for IERC20;

    function farm(
        address[] calldata tokens,
        uint[] calldata depositAmounts,
        uint[] calldata borrowAmounts,
        address transformer
    ) external {

    }

}