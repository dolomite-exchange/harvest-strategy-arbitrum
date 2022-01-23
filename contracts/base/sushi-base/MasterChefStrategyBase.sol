pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../interface/IStrategy.sol";
import "../interface/IVault.sol";
import "../upgradability/BaseUpgradeableStrategy.sol";
import "./interfaces/IMasterChef.sol";


contract MasterChefStrategyBase is IStrategy, BaseUpgradeableStrategy {

    // TODO - skim down the inheritance files' duplicated code

}
