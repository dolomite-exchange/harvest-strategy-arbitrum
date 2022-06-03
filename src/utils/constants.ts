import { BaseContract } from 'ethers';
import {
  IBVault, IBVault__factory,
  ICrvRewardNotifier,
  ICrvRewardNotifier__factory,
  IERC20,
  IERC20__factory,
  IEursUsdPool,
  IEursUsdPool__factory,
  IGauge,
  IGauge__factory, IMiniChefV2, IMiniChefV2__factory,
  IRenWbtcPool,
  IRenWbtcPool__factory, IStargateFarmingPool, IStargateFarmingPool__factory, IStargateRouter, IStargateRouter__factory,
  ITriCryptoPool,
  ITriCryptoPool__factory,
  ITwoPool,
  ITwoPool__factory,
  IUniswapV2Router02,
  IUniswapV2Router02__factory,
  IUniswapV3Router,
  IUniswapV3Router__factory,
  IWETH,
  IWETH__factory, PotPoolV1, PotPoolV1__factory,
  VaultV2,
  VaultV2__factory, VaultV2Payable, VaultV2Payable__factory,
} from '../types';

// ************************* External Contract Addresses *************************

export const BALANCER_VAULT = new BaseContract(
  '0xBA12222222228d8Ba445958a75a0704d566BF2C8',
  IBVault__factory.createInterface(),
) as IBVault;

export const CRV = new BaseContract(
  '0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_EURS_USD_TOKEN = new BaseContract(
  '0x3dFe1324A0ee9d86337d06aEB829dEb4528DB9CA',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_EURS_USD_POOL = new BaseContract(
  '0xA827a652Ead76c6B0b3D19dba05452E06e25c27e',
  IEursUsdPool__factory.createInterface(),
) as IEursUsdPool;

export const CRV_EURS_USD_POOL_GAUGE = new BaseContract(
  '0x37C7ef6B0E23C9bd9B620A6daBbFEC13CE30D824',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_REN_WBTC_POOL = new BaseContract(
  '0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb',
  IRenWbtcPool__factory.createInterface(),
) as IRenWbtcPool;

// address is indeed the same as REN_WBTC_POOL
export const CRV_REN_WBTC_TOKEN = new BaseContract(
  '0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_REN_WBTC_POOL_GAUGE = new BaseContract(
  '0xC2b1DF84112619D190193E48148000e3990Bf627',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_REWARD_NOTIFIER = new BaseContract(
  '0x9044E12fB1732f88ed0c93cfa5E9bB9bD2990cE5',
  ICrvRewardNotifier__factory.createInterface(),
) as ICrvRewardNotifier;

export const CRV_TRI_CRYPTO_TOKEN = new BaseContract(
  '0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_TRI_CRYPTO_GAUGE = new BaseContract(
  '0x97E2768e8E73511cA874545DC5Ff8067eB19B787',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_TRI_CRYPTO_POOL = new BaseContract(
  '0x960ea3e3C7FB317332d990873d354E18d7645590',
  ITriCryptoPool__factory.createInterface(),
) as ITriCryptoPool;

export const CRV_TWO_POOL = new BaseContract(
  '0x7f90122BF0700F9E7e1F688fe926940E8839F353',
  ITwoPool__factory.createInterface(),
) as ITwoPool;

// address is the same as TWO_POOL
export const CRV_TWO_POOL_TOKEN = new BaseContract(
  '0x7f90122BF0700F9E7e1F688fe926940E8839F353',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_TWO_POOL_GAUGE = new BaseContract(
  '0xbF7E49483881C76487b0989CD7d9A8239B20CA41',
  IGauge__factory.createInterface(),
) as IGauge;

export const DAI = new BaseContract(
  '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
  IERC20__factory.createInterface(),
) as IERC20;

export const aiFARM = new BaseContract(
  '0x9dCA587dc65AC0a043828B0acd946d71eb8D46c1',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_DAI_SLP = new BaseContract(
  '0x692a0B300366D1042679397e40f3d2cb4b8F7D30',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_G_OHM_SLP = new BaseContract(
  '0xaa5bD49f2162ffdC15634c87A77AC67bD51C6a6D',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_MAGIC_SLP = new BaseContract(
  '0xB7E50106A5bd3Cf21AF210A755F9C8740890A8c9',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_MIM_SLP = new BaseContract(
  '0xb6DD51D5425861C808Fd60827Ab6CFBfFE604959',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_SPELL_SLP = new BaseContract(
  '0x8f93Eaae544e8f5EB077A1e09C1554067d9e2CA8',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_SUSHI_SLP = new BaseContract(
  '0x3221022e37029923aCe4235D812273C5A42C322d',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_USDC_SLP = new BaseContract(
  '0x905dfCD5649217c42684f23958568e533C711Aa3',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_USDT_SLP = new BaseContract(
  '0xCB0E5bFa72bBb4d16AB5aA0c60601c438F04b4ad',
  IERC20__factory.createInterface(),
) as IERC20;

export const ETH_WBTC_SLP = new BaseContract(
  '0x515e252b2b5c22b4b2b6Df66c2eBeeA871AA4d69',
  IERC20__factory.createInterface(),
) as IERC20;

export const G_OHM = new BaseContract(
  '0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1',
  IERC20__factory.createInterface(),
) as IERC20;

export const LINK = new BaseContract(
  '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4',
  IERC20__factory.createInterface(),
) as IERC20;

export const MAGIC = new BaseContract(
  '0x539bdE0d7Dbd336b79148AA742883198BBF60342',
  IERC20__factory.createInterface(),
) as IERC20;

export const MIM = new BaseContract(
  '0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A',
  IERC20__factory.createInterface(),
) as IERC20;

export const SPELL = new BaseContract(
  '0x3E6648C5a70A150A88bCE65F4aD4d506Fe15d2AF',
  IERC20__factory.createInterface(),
) as IERC20;

export const STARGATE_REWARD_POOL = new BaseContract(
  '0xeA8DfEE1898a7e0a59f7527F076106d7e44c2176',
  IStargateFarmingPool__factory.createInterface(),
) as IStargateFarmingPool;

export const STARGATE_ROUTER = new BaseContract(
  '0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614',
  IStargateRouter__factory.createInterface(),
) as IStargateRouter;

export const STARGATE_S_USDC = new BaseContract(
  '0x892785f33CdeE22A30AEF750F285E18c18040c3e',
  IERC20__factory.createInterface(),
) as IERC20;

export const STARGATE_S_USDT = new BaseContract(
  '0xB6CfcF89a7B22988bfC96632aC2A9D6daB60d641',
  IERC20__factory.createInterface(),
) as IERC20;

export const STG = new BaseContract(
  '0x6694340fc020c5E6B96567843da2df01b2CE1eb6',
  IERC20__factory.createInterface(),
) as IERC20;

export const SUSHI = new BaseContract(
  '0xd4d42F0b6DEF4CE0383636770eF773390d85c61A',
  IERC20__factory.createInterface(),
) as IERC20;

export const SUSHI_MINI_CHEF = new BaseContract(
  '0xF4d73326C13a4Fc5FD7A064217e12780e9Bd62c3',
  IMiniChefV2__factory.createInterface(),
) as IMiniChefV2;

export const SUSHI_ROUTER = new BaseContract(
  '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
  IUniswapV2Router02__factory.createInterface(),
) as IUniswapV2Router02;

export const UNI = new BaseContract(
  '0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0',
  IERC20__factory.createInterface(),
) as IERC20;

export const UNISWAP_V3_ROUTER = new BaseContract(
  '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  IUniswapV3Router__factory.createInterface(),
) as IUniswapV3Router;

export const USDC = new BaseContract(
  '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8',
  IERC20__factory.createInterface(),
) as IERC20;

export const USDT = new BaseContract(
  '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
  IERC20__factory.createInterface(),
) as IERC20;

export const WBTC = new BaseContract(
  '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
  IERC20__factory.createInterface(),
) as IERC20;

export const WETH = new BaseContract(
  '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  IWETH__factory.createInterface(),
) as IWETH;

// ************************* Network Addresses *************************

export const CrvWhaleAddress = '0x4A65e76bE1b4e8dd6eF618277Fa55200e3F8F20a';
export const DaiWhaleAddress = '0xc5ed2333f8a2C351fCA35E5EBAdb2A82F5d254C3';
export const GOhmWhaleAddress = '0x33eBB62DC9ddBf6B8F3C0efdF5BccC2e7AC60211';
export const MagicWhaleAddress = '0x482729215AAF99B3199E41125865821ed5A4978a';
export const MimWhaleAddress = '0x287239c1C1BD4F9D3691366A4B45F0da4b527E9a';
export const SpellWhaleAddress = '0x6c469df3b69ddf8be1de915f8d74e2191fbd6304';
export const StgWhaleAddress = '0x67fc8c432448f9a8d541c17579ef7a142378d5ad';
export const SushiWhaleAddress = '0x871ea9aF361ec1104489Ed96438319b46E5FB4c6';
export const UsdcWhaleAddress = '0xCe2CC46682E9C6D5f174aF598fb4931a9c0bE68e';
export const UsdtWhaleAddress = '0xf89d7b9c864f589bbF53a82105107622B35EaA40';
export const WbtcWhaleAddress1 = '0xc5ed2333f8a2C351fCA35E5EBAdb2A82F5d254C3';
export const WbtcWhaleAddress2 = '0xEDad4B1F3eDc83EeD2BeCCA6a9EFFBAB766fCC96';

// ************************* Harvest Contract Addresses *************************

export const ControllerV1Address = '0xD5C5017659Af1E53b48aE9d55b02756342A7d4fF';
export const EthPayableVaultProxyAddress = '0xb695801B9D55A7818debF063e1E49D31C2761945';
export const GovernorAddress = '0xb39710a1309847363b9cBE5085E427cc2cAeE563';
export const PotPoolV1ImplementationAddress = '0x247de9A108639278Eb0348baf15178593921d73f';
export const ProfitSharingReceiverV1Address = '0x5F11EfDF4422B548007Cae9919b0b38c35fa6BE7';
export const RewardForwarderV1Address = '0x26B27e13E38FA8F8e43B8fc3Ff7C601A8aA0D032';
export const StorageAddress = '0xc1234a98617385D1a4b87274465375409f7E248f';
export const UniversalLiquidatorAddress = '0xe5dcf0eB836adb04FF58A472B6924fE941c4Fe76';
export const VaultV2ImplementationAddress = '0x2C328Fc08b4F64eA1B603875F3e0BEEd90fC83B9';
export const WethVaultProxyAddress = '0x4e1B3DE0cEe69AaD99f79D7cE10Bf243A7BD3A07';

// ************************* Harvest Contract Addresses *************************

export const EthVaultProxy = new BaseContract(
  EthPayableVaultProxyAddress,
  VaultV2Payable__factory.createInterface(),
) as VaultV2Payable;

export const PotPoolV1Implementation = new BaseContract(
  PotPoolV1ImplementationAddress,
  PotPoolV1__factory.createInterface(),
) as PotPoolV1;

export const VaultV2Implementation = new BaseContract(
  VaultV2ImplementationAddress,
  VaultV2__factory.createInterface(),
) as VaultV2;

// ************************* Harvest Params *************************

export const DefaultImplementationDelay = 60 * 60 * 12; // 12 hours
