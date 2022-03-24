pragma solidity ^0.5.4;


interface ITriCryptoPool {

    function add_liquidity(uint[3] calldata amounts, uint min_mint_amount) external;

    function coins(uint i) external view returns (address);

    function balances(uint i) external view returns (uint256);

    function D() external view returns (uint256);

    function price_oracle(uint _k) external view returns (uint256);

    function price_scale(uint _k) external view returns (uint256);

    function exchange(
        uint _inputIndex,
        uint _outputIndex,
        uint _inputAmount,
        uint _minOutputAmount,
        bool _useEther
    ) external payable;
}
