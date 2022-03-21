pragma solidity ^0.5.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./inheritance/Governable.sol";

import "./interfaces/IController.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IVault.sol";

import "./RewardForwarderV1.sol";


contract ControllerV1 is IController, Governable {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    // external parties
    address public targetToken;
    address public rewardForwarder;
    address public universalLiquidator;
    address public dolomiteYieldFarmingRouter;

    uint256 public nextImplementationDelay;

    /// 15% of fees captured go to iFARM stakers
    uint256 public profitSharingNumerator = 1500;
    uint256 public nextProfitSharingNumerator = 0;
    uint256 public nextProfitSharingNumeratorTimestamp = 0;

    /// 5% of fees captured go to strategists
    uint256 public strategistFeeNumerator = 500;
    uint256 public nextStrategistFeeNumerator = 0;
    uint256 public nextStrategistFeeNumeratorTimestamp = 0;

    /// 5% of fees captured go to the devs of the platform
    uint256 public platformFeeNumerator = 500;
    uint256 public nextPlatformFeeNumerator = 0;
    uint256 public nextPlatformFeeNumeratorTimestamp = 0;

    uint256 public constant FEE_DENOMINATOR = 10000;

    // [Grey list]
    // An EOA can safely interact with the system no matter what.
    // If you're using Metamask, you're using an EOA.
    // Only smart contracts may be affected by this grey list.
    //
    // This contract will not be able to ban any EOA from the system
    // even if an EOA is being added to the greyList, he/she will still be able
    // to interact with the whole system as if nothing happened.
    // Only smart contracts will be affected by being added to the greyList.
    mapping (address => bool) public greyList;

    /// @notice This mapping allows certain contracts to stake on a user's behalf
    mapping (address => bool) public stakingWhiteList;

    // All vaults that we have
    mapping (address => bool) public vaults;

    // All strategies that we have
    mapping (address => bool) public strategies;

    // All eligible hardWorkers that we have
    mapping (address => bool) public hardWorkers;

    event QueueProfitSharingNumeratorChange(uint profitSharingNumerator, uint validAtTimestamp);
    event ConfirmProfitSharingNumeratorChange(uint profitSharingNumerator);

    event QueueStrategistFeeNumeratorChange(uint strategistFeeNumerator, uint validAtTimestamp);
    event ConfirmStrategistFeeNumeratorChange(uint strategistFeeNumerator);

    event QueuePlatformFeeNumeratorChange(uint platformFeeNumerator, uint validAtTimestamp);
    event ConfirmPlatformFeeNumeratorChange(uint platformFeeNumerator);

    event AddedStakingContract(address indexed stakingContract);
    event RemovedStakingContract(address indexed stakingContract);

    modifier validVault(address _vault){
        require(vaults[_vault], "vault does not exist");
        _;
    }

    modifier confirmSharePrice(
        address vault,
        uint256 _hint,
        uint256 _deviationNumerator,
        uint256 _deviationDenominator
    ) {
        uint256 sharePrice = IVault(vault).getPricePerFullShare();
        uint256 resolution = 1e18;
        if (sharePrice > _hint) {
            require(
                sharePrice.mul(resolution).div(_hint) <= _deviationNumerator.mul(resolution).div(_deviationDenominator),
                "share price deviation"
            );
        } else {
            require(
                _hint.mul(resolution).div(sharePrice) <= _deviationNumerator.mul(resolution).div(_deviationDenominator),
                "share price deviation"
            );
        }
        _;
    }

    modifier onlyHardWorkerOrGovernance() {
        require(hardWorkers[msg.sender] || (msg.sender == governance()),
            "only hard worker can call this");
        _;
    }

    constructor(
        address _storage,
        address _targetToken,
        address _rewardForwarder,
        address _universalLiquidator,
        uint _nextImplementationDelay
    )
    Governable(_storage)
    public {
        require(_rewardForwarder != address(0), "feeRewardForwarder should not be empty");
        targetToken = _targetToken;
        rewardForwarder = _rewardForwarder;
        universalLiquidator = _universalLiquidator;
        nextImplementationDelay = _nextImplementationDelay;
    }

    function hasVault(address _vault) external view returns (bool) {
        return vaults[_vault];
    }

    function hasStrategy(address _strategy) external view returns (bool) {
        return strategies[_strategy];
    }

    // Only smart contracts will be affected by the greyList.
    function addToGreyList(address _target) public onlyGovernance {
        greyList[_target] = true;
    }

    function removeFromGreyList(address _target) public onlyGovernance {
        greyList[_target] = false;
    }

    function addToStakingWhiteList(address _target) public onlyGovernance {
        require(
            !stakingWhiteList[_target],
            "_target cannot already be staking"
        );

        stakingWhiteList[_target] = true;
        emit AddedStakingContract(_target);
    }

    function removeFromStakingWhiteList(address _target) public onlyGovernance {
        require(
            stakingWhiteList[_target],
            "_target must already be staking"
        );

        stakingWhiteList[_target] = false;
        emit RemovedStakingContract(_target);
    }

    function setRewardForwarder(address _rewardForwarder) public onlyGovernance {
        require(_rewardForwarder != address(0), "new reward forwarder should not be empty");
        rewardForwarder = _rewardForwarder;
    }

    function setTargetToken(address _targetToken) public onlyGovernance {
        require(_targetToken != address(0), "new target token should not be empty");
        targetToken = _targetToken;
    }

    function setUniversalLiquidator(address _universalLiquidator) public onlyGovernance {
        require(_universalLiquidator != address(0), "new universal liquidator should not be empty");
        universalLiquidator = _universalLiquidator;
    }

    function setDolomiteYieldFarmingRouter(address _dolomiteYieldFarmingRouter) public onlyGovernance {
        require(_dolomiteYieldFarmingRouter != address(0), "new reward forwarder should not be empty");
        dolomiteYieldFarmingRouter = _dolomiteYieldFarmingRouter;
    }

    function addVaultAndStrategy(address _vault, address _strategy) external onlyGovernance {
        _addVaultAndStrategy(_vault, _strategy);
    }

    function addVaultsAndStrategies(
        address[] calldata _vaults,
        address[] calldata _strategies
    ) external onlyGovernance {
        require(
            _vaults.length == _strategies.length,
            "invalid vaults/strategies length"
        );
        for (uint i = 0; i < _vaults.length; i++) {
            _addVaultAndStrategy(_vaults[i], _strategies[i]);
        }
    }

    function getPricePerFullShare(address _vault) public view returns (uint256) {
        return IVault(_vault).getPricePerFullShare();
    }

    function doHardWork(
        address _vault,
        uint256 _hint,
        uint256 _deviationNumerator,
        uint256 _deviationDenominator
    )
    external
    validVault(_vault)
    onlyHardWorkerOrGovernance
    confirmSharePrice(_vault, _hint, _deviationNumerator, _deviationDenominator) {
        uint256 oldSharePrice = IVault(_vault).getPricePerFullShare();
        IVault(_vault).doHardWork();
        emit SharePriceChangeLog(
            _vault,
            IVault(_vault).strategy(),
            oldSharePrice,
            IVault(_vault).getPricePerFullShare(),
            block.timestamp
        );
    }

    function addHardWorker(address _worker) public onlyGovernance {
        require(_worker != address(0), "_worker must be defined");
        hardWorkers[_worker] = true;
    }

    function removeHardWorker(address _worker) public onlyGovernance {
        require(_worker != address(0), "_worker must be defined");
        hardWorkers[_worker] = false;
    }

    function withdrawAll(
        address _vault,
        uint256 _hint,
        uint256 _deviationNumerator,
        uint256 _deviationDenominator
    )
    external
    confirmSharePrice(_vault, _hint, _deviationNumerator, _deviationDenominator)
    onlyGovernance
    validVault(_vault) {
        IVault(_vault).withdrawAll();
    }

    function setStrategy(
        address _vault,
        address _strategy,
        uint256 _hint,
        uint256 _deviationNumerator,
        uint256 _deviationDenominator
    )
    external
    confirmSharePrice(_vault, _hint, _deviationNumerator, _deviationDenominator)
    onlyGovernance
    validVault(_vault) {
        IVault(_vault).setStrategy(_strategy);
    }

    // transfers token in the controller contract to the governance
    function salvage(address _token, uint256 _amount) external onlyGovernance {
        IERC20(_token).safeTransfer(governance(), _amount);
    }

    function salvageStrategy(address _strategy, address _token, uint256 _amount) external onlyGovernance {
        // the strategy is responsible for maintaining the list of
        // salvageable tokens, to make sure that governance cannot come
        // in and take away the coins
        IStrategy(_strategy).salvageToken(governance(), _token, _amount);
    }

    function profitSharingDenominator() public view returns (uint) {
        // keep the interface for this function as a `view` for now, in case it changes in the future
        return FEE_DENOMINATOR;
    }

    function strategistFeeDenominator() public view returns (uint) {
        // keep the interface for this function as a `view` for now, in case it changes in the future
        return FEE_DENOMINATOR;
    }

    function platformFeeDenominator() public view returns (uint) {
        // keep the interface for this function as a `view` for now, in case it changes in the future
        return FEE_DENOMINATOR;
    }

    function setProfitSharingNumerator(uint _profitSharingNumerator) public onlyGovernance {
        require(
            _profitSharingNumerator + strategistFeeNumerator + platformFeeNumerator < FEE_DENOMINATOR,
            "invalid profit sharing fee numerator"
        );

        nextProfitSharingNumerator = _profitSharingNumerator;
        nextProfitSharingNumeratorTimestamp = block.timestamp + nextImplementationDelay;
        emit QueueProfitSharingNumeratorChange(nextProfitSharingNumerator, nextProfitSharingNumeratorTimestamp);
    }

    function confirmSetProfitSharingNumerator() public onlyGovernance {
        require(
            nextProfitSharingNumerator != 0
            && nextProfitSharingNumeratorTimestamp != 0
            && block.timestamp >= nextProfitSharingNumeratorTimestamp,
            "invalid timestamp or no new profit sharing numerator confirmed"
        );
        profitSharingNumerator = nextProfitSharingNumerator;
        nextProfitSharingNumerator = 0;
        nextProfitSharingNumeratorTimestamp = 0;
        emit ConfirmProfitSharingNumeratorChange(profitSharingNumerator);
    }

    function setStrategistFeeNumerator(uint _strategistFeeNumerator) public onlyGovernance {
        require(
            _strategistFeeNumerator + platformFeeNumerator + profitSharingNumerator < FEE_DENOMINATOR,
            "invalid strategist fee numerator"
        );

        nextStrategistFeeNumerator = _strategistFeeNumerator;
        nextStrategistFeeNumeratorTimestamp = block.timestamp + nextImplementationDelay;
        emit QueueStrategistFeeNumeratorChange(nextStrategistFeeNumerator, nextStrategistFeeNumeratorTimestamp);
    }

    function confirmSetStrategistFeeNumerator() public onlyGovernance {
        require(
            nextStrategistFeeNumerator != 0
            && nextStrategistFeeNumeratorTimestamp != 0
            && block.timestamp >= nextStrategistFeeNumeratorTimestamp,
            "invalid timestamp or no new strategist fee numerator confirmed"
        );
        strategistFeeNumerator = nextStrategistFeeNumerator;
        nextStrategistFeeNumerator = 0;
        nextStrategistFeeNumeratorTimestamp = 0;
        emit ConfirmStrategistFeeNumeratorChange(strategistFeeNumerator);
    }

    function setPlatformFeeNumerator(uint _platformFeeNumerator) public onlyGovernance {
        require(
            _platformFeeNumerator + strategistFeeNumerator + profitSharingNumerator < FEE_DENOMINATOR,
            "invalid platform fee numerator"
        );

        nextPlatformFeeNumerator = _platformFeeNumerator;
        nextPlatformFeeNumeratorTimestamp = block.timestamp + nextImplementationDelay;
        emit QueuePlatformFeeNumeratorChange(nextPlatformFeeNumerator, nextPlatformFeeNumeratorTimestamp);
    }

    function confirmSetPlatformFeeNumerator() public onlyGovernance {
        require(
            nextPlatformFeeNumerator != 0
            && nextPlatformFeeNumeratorTimestamp != 0
            && block.timestamp >= nextPlatformFeeNumeratorTimestamp,
            "invalid timestamp or no new platform fee numerator confirmed"
        );
        platformFeeNumerator = nextPlatformFeeNumerator;
        nextPlatformFeeNumerator = 0;
        nextPlatformFeeNumeratorTimestamp = 0;
        emit ConfirmPlatformFeeNumeratorChange(platformFeeNumerator);
    }

    function _addVaultAndStrategy(address _vault, address _strategy) internal {
        require(_vault != address(0), "new vault shouldn't be empty");
        require(!vaults[_vault], "vault already exists");
        require(!strategies[_strategy], "strategy already exists");
        require(_strategy != address(0), "new strategy shouldn't be empty");

        vaults[_vault] = true;
        strategies[_strategy] = true;

        // no need to protect against sandwich, because there will be no call to withdrawAll
        // as the vault and strategy is brand new
        IVault(_vault).setStrategy(_strategy);
    }
}
