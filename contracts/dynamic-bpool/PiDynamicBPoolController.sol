// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../PiBPoolController.sol";

contract PiDynamicBPoolController is PiBPoolController {

    bytes4 public constant BIND_SIG = bytes4(keccak256(bytes("bind(address,uint256,uint256,uint256,uint256)")));
    bytes4 public constant UNBIND_SIG = bytes4(keccak256(bytes('unbind(address)')));

    struct DynamicWeightInput {
        address token;
        uint targetDenorm;
        uint fromTimestamp;
        uint targetTimestamp;
    }

    constructor(address _bpool, address _bpoolWrapper) public PiBPoolController(_bpool, _bpoolWrapper) {

    }

    /**
    * @notice Call bind of pool
    * @param token Token for bind
    * @param balance Initial balance
    * @param targetDenorm Target weight
    * @param fromTimestamp From timestamp of dynamic weight
    * @param targetTimestamp Target timestamp of dynamic weight
    */
    function bind(address token, uint balance, uint targetDenorm, uint fromTimestamp, uint targetTimestamp)
        external
    {
        IERC20(token).transferFrom(msg.sender, address(this), balance);
        IERC20(token).approve(address(bpool), balance);
        bpool.bind(token, balance, targetDenorm, fromTimestamp, targetTimestamp);
    }

    /**
    * @notice Call setDynamicWeight for several tokens
    * @param _dynamicWeights Tokens dynamic weights configs
    */
    function setDynamicWeightList(DynamicWeightInput[] memory _dynamicWeights) external onlyOwner {
        uint256 len = _dynamicWeights.length;
        for (uint256 i = 0; i < len; i++) {
            bpool.setDynamicWeight(
                _dynamicWeights[i].token,
                _dynamicWeights[i].targetDenorm,
                _dynamicWeights[i].fromTimestamp,
                _dynamicWeights[i].targetTimestamp
            );
        }
    }

    /**
    * @notice Permissionless function for unbind tokens which has reached MIN_WEIGHT
    * @param _token Token to unbind
    */
    function unbindNotActualToken(address _token) external {
        require(bpool.getDenormalizedWeight(_token) == bpool.MIN_WEIGHT(), "DENORM_MIN");
        (, uint256 targetTimestamp, , ) = bpool.getDynamicWeightSettings(_token);
        require(block.timestamp > targetTimestamp, "TIMESTAMP_MORE_THEN_TARGET");

        uint256 tokenBalance = bpool.getBalance(_token);

        bpool.unbind(_token);
        (, , , address communityWallet) = bpool.getCommunityFee();
        IERC20(_token).transfer(communityWallet, tokenBalance);
    }

    function _checkSignature(bytes4 signature) internal pure override {
        require(signature != BIND_SIG && signature != UNBIND_SIG && signature != CALL_VOTING_SIG, "SIGNATURE_NOT_ALLOWED");
    }
}
