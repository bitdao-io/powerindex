pragma solidity 0.6.12;

abstract contract BPoolInterface {
    function approve(address spender, uint256 amount) external virtual returns (bool);
    function transfer(address recipient, uint256 amount) external virtual returns (bool);
    function transferFrom(address spender, address recipient, uint256 amount) external virtual returns (bool);

    function joinPool(uint poolAmountOut, uint[] calldata maxAmountsIn) external virtual;
    function exitPool(uint poolAmountIn, uint[] calldata minAmountsOut) external virtual;
    function swapExactAmountIn(address, uint, address, uint, uint) external virtual returns (uint, uint);
    function swapExactAmountOut(address, uint, address, uint, uint) external virtual returns (uint, uint);
    function joinswapExternAmountIn(address, uint, uint) external virtual returns (uint);
    function joinswapPoolAmountOut(address, uint, uint) external virtual returns (uint);
    function exitswapPoolAmountIn(address, uint, uint) external virtual returns (uint);
    function exitswapExternAmountOut(address, uint, uint) external virtual returns (uint);
    function calcInGivenOut(uint, uint, uint, uint, uint, uint) public pure virtual returns (uint);
    function getDenormalizedWeight(address) external view virtual returns (uint);
    function getBalance(address) external view virtual returns (uint);
    function getSwapFee() external view virtual returns (uint);
    function totalSupply() external view virtual returns (uint);
    function balanceOf(address) external view virtual returns (uint);
    function getTotalDenormalizedWeight() external view virtual returns (uint);

    function getCommunityFee() external view virtual returns (uint, uint, uint, address);
    function calcAmountWithCommunityFee(uint, uint, address) external view virtual returns (uint, uint);
    function getRestrictions() external view virtual returns (address);

    function getCurrentTokens() external view virtual returns (address[] memory tokens);
    function getFinalTokens() external view virtual returns (address[] memory tokens);

    function getController() external view virtual returns (address);
    function setController(address) external virtual;

    function bind(address, uint, uint) external virtual;
    function unbind(address) external virtual;
}
