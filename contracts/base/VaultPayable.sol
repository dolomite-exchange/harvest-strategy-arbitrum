pragma solidity ^0.5.16;

import "./interface/weth/Weth9.sol";
import "./Vault.sol";


contract VaultPayable is Vault {
    using Address for address payable;

    uint private _shouldWithdrawToETH = 1;

    function() external payable {
        require(msg.sender == underlying(), "invalid sender for default payable");
    }

    function depositETH() external defense payable {
        _deposit(msg.value, msg.sender, msg.sender);
    }

    function depositETHFor(address holder) external defense payable {
        _deposit(msg.value, msg.sender, holder);
    }

    function withdraw(uint256 numberOfShares) external defense {
        _shouldWithdrawToETH = 1;
        _withdraw(numberOfShares);
    }

    function withdrawETH(uint256 numberOfShares) external defense {
        _shouldWithdrawToETH = 2;
        _withdraw(numberOfShares);
    }

    function _transferUnderlyingOut(uint amount) internal {
        if (_shouldWithdrawToETH == 2) {
            WETH9(underlying()).withdraw(amount);
            msg.sender.sendValue(amount);
        } else {
            IERC20(underlying()).safeTransfer(msg.sender, amount);
        }
    }

    function _deposit(uint256 amount, address sender, address beneficiary) internal {
        require(amount > 0, "Cannot deposit 0");
        require(beneficiary != address(0), "holder must be defined");

        if (address(strategy()) != address(0)) {
            require(IStrategy(strategy()).depositArbCheck(), "Too much arb");
        }

        uint256 toMint = totalSupply() == 0
        ? amount
        : amount.mul(totalSupply()).div(underlyingBalanceWithInvestment());

        _mint(beneficiary, toMint);

        // if user has sent ETH, then we assume ETH is the way user deposits
        if (msg.value != 0) {
            require(msg.value == amount, "amount doesn't match msg value");
            WETH9(underlying()).deposit.value(msg.value)();
        } else {
            IERC20(underlying()).safeTransferFrom(sender, address(this), amount);
        }

        // update the contribution amount for the beneficiary
        emit Deposit(beneficiary, amount);
    }

}
