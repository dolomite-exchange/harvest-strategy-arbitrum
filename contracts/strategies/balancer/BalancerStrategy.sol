pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../base/interfaces/uniswap/IUniswapV2Router02.sol";
import "../../base/interfaces/IStrategy.sol";
import "../../base/interfaces/IVault.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/interfaces/uniswap/IUniswapV2Pair.sol";
import "./interfaces/IBVault.sol";

contract BalancerStrategy is IStrategy, BaseUpgradeableStrategy {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POOLID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
    bytes32 internal constant _BVAULT_SLOT = 0x85cbd475ba105ca98d9a2db62dcf7cf3c0074b36303ef64160d68a3e0fdd3c67;
    bytes32 internal constant _WEIGHTS_SLOT = 0x836a60b998dc8c21b3cceb353eb01320c0886b91db35570b7b27d9d6a769400b;

    // this would be reset on each upgrade
    mapping(address => address[]) public swapRoutes;

    constructor() public BaseUpgradeableStrategy() {
        assert(_POOLID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
        assert(_BVAULT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.bVault")) - 1));
        assert(_WEIGHTS_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.weights")) - 1));
    }

    /**
     * @param _weights  the weights to be applied for each buybackToken. For example [100, 300] applies 25% to
     *                  buybackTokens[0] and 75% to buybackTokens[1]
     */
    function initializeStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address [] memory _rewardTokens,
        address _bVault,
        bytes32 _poolID,
        uint[] memory _weights
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens
        );

        (address _lpt,) = IBVault(_bVault).getPool(_poolID);
        require(_lpt == _underlying, "Underlying mismatch");

        _setPoolId(_poolID);
        _setBVault(_bVault);
        _setWeights(_weights);

        (IERC20[] memory erc20Tokens,,) = IBVault(bVault()).getPoolTokens(poolId());
        require(
            erc20Tokens.length == _weights.length,
            "weights length must equal ERC20 tokens length"
        );
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function underlyingBalance() internal view returns (uint256 bal) {
        bal = IERC20(underlying()).balanceOf(address(this));
    }

    function isUnsalvageableToken(address token) public view returns (bool) {
        return (isRewardToken(token) || token == underlying());
    }

    // We assume that all the tradings can be done on Uniswap
    function _liquidateReward() internal {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            if (!sell() || rewardBalance < sellFloor()) {
                // Profits can be disabled for possible simplified and rapid exit
                emit ProfitsNotCollected(_rewardTokens[i], sell(), rewardBalance < sellFloor());
                return;
            }

            (IERC20[] memory erc20Tokens,,) = IBVault(bVault()).getPoolTokens(poolId());

            address[] memory tokens = new address[](erc20Tokens.length);
            for (uint j = 0; j < tokens.length; j++) {
                tokens[j] = address(erc20Tokens[j]);
            }

            uint[] memory buybackAmounts = _notifyProfitAndBuybackInRewardTokenWithWeights(
                _rewardTokens[i],
                rewardBalance,
                tokens,
                weights()
            );

            // provide token1 and token2 to Balancer
            for (uint j = 0; j < tokens.length; j++) {
                IERC20(address(tokens[j])).safeApprove(bVault(), 0);
                IERC20(address(tokens[j])).safeApprove(bVault(), buybackAmounts[j]);
            }

            IAsset[] memory assets = new IAsset[](tokens.length);
            uint256[] memory amountsIn = new uint256[](tokens.length);
            for (uint j = 0; j < tokens.length; j++) {
                assets[j] = IAsset(tokens[j]);
                amountsIn[j] = buybackAmounts[j];
            }

            IBVault.JoinKind joinKind = IBVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT;
            uint256 minAmountOut = 1;
            bytes memory userData = abi.encode(joinKind, amountsIn, minAmountOut);

            IBVault.JoinPoolRequest memory request;
            request.assets = assets;
            request.maxAmountsIn = amountsIn;
            request.userData = userData;
            request.fromInternalBalance = false;

            IBVault(bVault()).joinPool(
                poolId(),
                address(this),
                address(this),
                request
            );
        }
    }

    /**
     * Withdraws all the asset to the vault
     */
    function withdrawAllToVault() public restricted {
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     * Withdraws all the asset to the vault
     */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount >= entireBalance) {
            withdrawAllToVault();
        } else {
            IERC20(underlying()).safeTransfer(vault(), amount);
        }
    }

    /**
     *   @notice We currently do not have a mechanism here to include the amount of reward that is accrued.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        return underlyingBalance();
    }

    /**
     *   Get the reward, sell it in exchange for underlying, invest what you got.
     *   It's not much, but it's honest work.
     *
     *   Note that although `onlyNotPausedInvesting` is not added here,
     *   calling `investAllUnderlying()` affectively blocks the usage of `doHardWork`
     *   when the investing is being paused by governance.
     */
    function doHardWork() external onlyNotPausedInvesting restricted {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            _liquidateReward();
        }
    }

    function liquidateAll() external onlyGovernance {
        _liquidateReward();
    }

    /**
     * Can completely disable claiming UNI rewards and selling. Good for emergency withdraw in the
     * simplest possible way.
     */
    function setSell(bool s) public onlyGovernance {
        _setSell(s);
    }

    /**
     * Sets the minimum amount of CRV needed to trigger a sale.
     */
    function setSellFloor(uint256 floor) public onlyGovernance {
        _setSellFloor(floor);
    }

    function _setPoolId(bytes32 _value) internal {
        setBytes32(_POOLID_SLOT, _value);
    }

    function poolId() public view returns (bytes32) {
        return getBytes32(_POOLID_SLOT);
    }

    function _setBVault(address _address) internal {
        setAddress(_BVAULT_SLOT, _address);
    }

    function _setWeights(uint[] memory _weights) internal {
        setUint256Array(_WEIGHTS_SLOT, _weights);
    }

    function weights() public view returns (uint[] memory) {
        return getUint256Array(_WEIGHTS_SLOT);
    }

    function bVault() public view returns (address) {
        return getAddress(_BVAULT_SLOT);
    }

    function setBytes32(bytes32 slot, bytes32 _value) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, _value)
        }
    }

    function getBytes32(bytes32 slot) internal view returns (bytes32 str) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            str := sload(slot)
        }
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}
