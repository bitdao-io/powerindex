pragma solidity 0.6.12;


import "./SafeUint.sol";


library CacheCheckpoints {

    /// @dev A checkpoint storing some data effective from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint192 data;
        // uint32 __reserved;
    }

    /// @dev A set of checkpoints and some arbitrary cached data
    struct Record {
        uint32 numCheckpoints;
        uint32 lastCheckpointBlock;
        // Abstract data (but NOT the last checkpoint data)
        uint192 cache;
        // Checkpoints by IDs
        mapping (uint32 => Checkpoint) checkpoints;
        // @dev Checkpoint IDs get counted from 1 (but not from 0) -
        // the 1st checkpoint has ID of 1, and the last checkpoint' ID is equal to `numCheckpoints`
    }

    /**
     * @dev Gets the latest data recorded in the given record
     */
    function getLatestData(Record storage record)
    internal view returns (uint192)
    {
        Record memory _record = record;
        return _record.numCheckpoints == 0
        ? 0
        : record.checkpoints[_record.numCheckpoints].data;
    }

    /**
     * @dev Returns the prior data written in the given record' checkpoints as of a block number
     * (reverts if the requested block has not been finalized)
     * @param record The record with checkpoints
     * @param blockNumber The block number to get the data at
     * @param checkpointId Optional ID of a checkpoint to first look into
     * @return The data effective as of the given block
     */
    function getPriorData(Record storage record, uint blockNumber, uint checkpointId)
    internal view returns (uint192)
    {
        uint32 blockNum = SafeUint.safeMinedBlockNum(blockNumber);
        Record memory _record = record;
        Checkpoint memory cp;

        // First check specific checkpoint, if it's provided
        if (checkpointId != 0) {
            require(checkpointId <= _record.numCheckpoints, "ChPoints: invalid checkpoint id");
            uint32 cpId = uint32(checkpointId);

            cp = record.checkpoints[cpId];
            if (cp.fromBlock == blockNum) {
                return cp.data;
            } else if (cp.fromBlock < blockNum) {
                if (cpId == _record.numCheckpoints) {
                    return cp.data;
                }
                uint32 nextFromBlock = record.checkpoints[cpId + 1].fromBlock;
                if (nextFromBlock > blockNum) {
                    return cp.data;
                }
            }
        }

        // Finally, search trough all checkpoints
        ( , uint192 data) = _findCheckpoint(record, _record.numCheckpoints, blockNum);
        return data;
    }

    /**
     * @dev Finds a checkpoint in the given record for the given block number
     * (reverts if the requested block has not been finalized)
     * @param record The record with checkpoints
     * @param blockNumber The block number to get the checkpoint at
     * @return id The checkpoint ID
     * @return data The checkpoint data
     */
    function findCheckpoint(Record storage record, uint blockNumber)
    internal view returns (uint32 id, uint192 data)
    {
        uint32 blockNum = SafeUint.safeMinedBlockNum(blockNumber);
        uint32 numCheckpoints = record.numCheckpoints;

        (id, data) = _findCheckpoint(record, numCheckpoints, blockNum);
    }

    /**
     * @dev Writes a checkpoint with given data to the given record and returns the checkpoint ID
     */
    function writeCheckpoint(Record storage record, uint192 data)
    internal returns (uint32 id)
    {
        uint32 blockNum = SafeUint.safeBlockNum(block.number);
        Record memory _record = record;

        if (_record.lastCheckpointBlock != blockNum) {
            _record.numCheckpoints = _record.numCheckpoints + 1; // overflow chance ignored
            record.numCheckpoints = _record.numCheckpoints;
            record.lastCheckpointBlock = blockNum;
        }
        record.checkpoints[_record.numCheckpoints] = Checkpoint(blockNum, data);
        id = _record.numCheckpoints;
    }

    /**
     * @dev Gets data cached in the given record
     */
    function getCache(Record storage record) internal view returns (uint192)
    {
        return record.cache;
    }

    /**
     * @dev Writes given data to the cache of the given record
     */
    function writeCache(Record storage record, uint192 data) internal
    {
        record.cache = data;
    }

    function _findCheckpoint(Record storage record, uint32 numCheckpoints, uint32 blockNum)
    private view returns (uint32, uint192)
    {
        Checkpoint memory cp;

        // Check special cases first
        if (numCheckpoints == 0) {
            return (0, 0);
        }
        cp = record.checkpoints[numCheckpoints];
        if (cp.fromBlock <= blockNum) {
            return (numCheckpoints, cp.data);
        }
        if (record.checkpoints[1].fromBlock > blockNum) {
            return (0, 0);
        }

        uint32 lower = 1;
        uint32 upper = numCheckpoints;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            cp = record.checkpoints[center];
            if (cp.fromBlock == blockNum) {
                return (center, cp.data);
            } else if (cp.fromBlock < blockNum) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return (lower, record.checkpoints[lower].data);
    }
}
