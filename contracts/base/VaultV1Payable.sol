pragma solidity ^0.5.16;

import "./interfaces/weth/Weth9.sol";
import "./VaultV1.sol";


contract VaultV1Payable is VaultV1 {
    using Address for address payable;

    bytes32 internal constant _SHOULD_WITHDRAW_TO_ETH_SLOT = 0xe921e128e6bbbc3334588b78cb5f3f10af6c1e18396e789a648bf7ef84c7b600;

    constructor() public {
        assert(_SHOULD_WITHDRAW_TO_ETH_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.shouldWithdrawToETH")) - 1));
    }

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
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 1);
        _withdraw(numberOfShares);
    }

    function withdrawETH(uint256 numberOfShares) external defense {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 2);
        _withdraw(numberOfShares);
    }

    function _transferUnderlyingOut(uint amount) internal {
        if (getUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT) == 2) {
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
