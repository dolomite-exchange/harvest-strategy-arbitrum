pragma solidity ^0.5.16;

import "./inheritance/Constants.sol";
import "./interfaces/weth/Weth9.sol";
import "./VaultV2.sol";


contract VaultV2Payable is VaultV2, Constants {
    using Address for address payable;

    bytes32 internal constant _SHOULD_WITHDRAW_TO_ETH_SLOT = 0xe921e128e6bbbc3334588b78cb5f3f10af6c1e18396e789a648bf7ef84c7b600;

    constructor() public {
        assert(_SHOULD_WITHDRAW_TO_ETH_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.shouldWithdrawToETH")) - 1));
    }

    function() external payable {
        require(msg.sender == underlying(), "invalid sender for default payable");
    }

    function initializeVault(
        address _storage,
        address _underlying,
        uint256 _toInvestNumerator,
        uint256 _toInvestDenominator
    ) public initializer {
        require(_underlying == WETH, "Invalid underlying, expected WETH");
        super.initializeVault(_storage, WETH, _toInvestNumerator, _toInvestDenominator);
    }

    function depositWithETH(address _receiver) external nonReentrant defense payable {
        _deposit(msg.value, msg.sender, _receiver);
    }

    function withdraw(uint256 _shares) external nonReentrant defense {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 1);
        _withdraw(_shares, msg.sender, msg.sender);
    }

    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256) {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 1);
        uint shares = _assetsToShares(_assets);
        _withdraw(shares, _receiver, _owner);
        return shares;
    }

    function withdrawToETH(
        uint256 _assets,
        address _receiver,
        address _owner
    ) external nonReentrant defense {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 2);
        _withdraw(_assetsToShares(_assets), _receiver, _owner);
    }

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256) {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 1);
        return _withdraw(_shares, _receiver, _owner);
    }

    function redeemToETH(
        uint256 _shares,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256) {
        setUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT, 2);
        return _withdraw(_shares, _receiver, _owner);
    }

    // ========================= Internal Functions =========================

    function _transferUnderlyingIn(address _sender, uint _amount) internal {
        // if user has sent ETH, then we assume ETH is the way user deposits
        if (msg.value != 0) {
            require(msg.value == _amount, "amount doesn't match msg value");
            WETH9(underlying()).deposit.value(msg.value)();
        } else {
            IERC20(underlying()).safeTransferFrom(_sender, address(this), _amount);
        }
    }

    function _transferUnderlyingOut(address _receiver, uint _amount) internal {
        if (getUint256(_SHOULD_WITHDRAW_TO_ETH_SLOT) == 2) {
            WETH9(underlying()).withdraw(_amount);
            address(uint160(_receiver)).sendValue(_amount);
        } else {
            IERC20(underlying()).safeTransfer(_receiver, _amount);
        }
    }
}
