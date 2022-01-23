pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "../interface/IController.sol";
import "../interface/IFeeRewardForwarder.sol";
import "../interface/IUniversalLiquidator.sol";
import "../interface/ILiquidatorRegistry.sol";
import "./BaseUpgradeableStrategy.sol";


contract BaseUpgradeableStrategyUL is BaseUpgradeableStrategy {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 internal constant _UL_REGISTRY_SLOT = 0x7a4b558e8ed4a66729f4a918db093413f0f1ae77c0de7c88bea8b99e084b2a17;
    bytes32 internal constant _UL_SLOT = 0xebfe408f65547b28326a79acf512c0f9a2bf4211ece39254d7c3ec96dd3dd242;

    mapping(address => mapping(address => address[])) public storedLiquidationPaths;
    mapping(address => mapping(address => bytes32[])) public storedLiquidationDexes;

    modifier restricted() {
        require(msg.sender == vault() || msg.sender == controller()
            || msg.sender == governance(),
            "The sender has to be the controller, governance, or vault");
        _;
    }

    /**
     * @dev This is only used in `investAllUnderlying()` The user can still freely withdraw from the strategy
     */
    modifier onlyNotPausedInvesting() {
        require(!pausedInvesting(), "Action blocked as the strategy is in emergency state");
        _;
    }

    constructor() public BaseUpgradeableStrategyStorage() {
        assert(_UL_REGISTRY_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.ULRegistry")) - 1));
        assert(_UL_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.UL")) - 1));
    }

    function initialize(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _rewardToken,
        uint256 _profitSharingNumerator,
        uint256 _profitSharingDenominator,
        bool _sell,
        uint256 _sellFloor
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardToken,
            _profitSharingNumerator,
            _profitSharingDenominator,
            _sell,
            _sellFloor
        );
    }

    function universalLiquidator() public view returns (address) {
        return IController(controller()).universalLiquidator();
    }
}
