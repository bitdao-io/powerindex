// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultDepositor4 {
  function add_liquidity(uint256[4] memory _amounts, uint256 _min_mint_amount) external virtual;

  function calc_token_amount(uint256[4] memory _amounts, bool _deposit) external view virtual returns (uint256);

  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 _i,
    uint256 _min_amount
  ) external virtual;
}
