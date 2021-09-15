// File: contracts/CurveRewards.sol

pragma solidity ^0.5.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";


/**
 * Changes made to the SynthetixReward contract
 *
 * UNI to lpToken, and make it as a parameter of the constructor instead of hardcoded.
 */
contract LPTokenWrapper {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public lpToken;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @notice  Can only called by the migrateStakeFor in the MigrationHelperRewardPool
     */
    function migrateStakeFor(address target, uint256 amountNewShare) internal  {
        _totalSupply = _totalSupply.add(amountNewShare);
        _balances[target] = _balances[target].add(amountNewShare);
    }

    function _stake(address user, uint256 amount) internal {
        _totalSupply = _totalSupply.add(amount);
        _balances[user] = _balances[user].add(amount);
        lpToken.safeTransferFrom(user, address(this), amount);
    }

    function _withdraw(address user, uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
        _balances[user] = _balances[user].sub(amount);
        lpToken.safeTransfer(user, amount);
    }
}
