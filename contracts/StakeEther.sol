// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

contract StakeEther {
    // Custom Errors
    error CannotSendZeroValue();
    error InsufficientContractBalance();
    error FailedTransfer();
    error MaxDurationExceeded();
    error NotOwner();
    error StakingPeriodNotOver();
    error StakingRewardsAlreadyClaimed();
    error ZeroAddressDetected();

    address private _owner;
    uint256 public constant MIN_DURATION = 4 weeks;
    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant SECONDS_IN_YEAR = MAX_DURATION * 24 * 60 * 60;
    // uint256 public constant MIN_STAKE = 1e18;
    uint64 public constant PRECISION_FACTOR = 1e18; // Scaling factor for precision
    uint8 public constant INTEREST_RATE = 2; // Representing 4% as 4

    struct Stake {
        uint256 stakeAmount; // in lowest denomination (1e18)
        uint256 stakeReward; // in lowest denomination (1e18)
        uint256 startTime; // in seconds
        uint256 vestingPeriod; // in seconds
        address staker;
        bool isStaked;
        bool isMature;
    }

    mapping(address => Stake) userStakes;

    // Events
    event StakeSuccessful(
        address indexed staker,
        uint256 amount,
        uint256 timeAtStaking
    );
    event WithdrawSuccessful(
        address indexed withdrawer,
        uint256 amount,
        uint256 timeAtWithdrawal
    );

    constructor() payable {
        _owner = msg.sender;
    }

    function stakeEther(uint256 _duration) external payable {
        // Perform sanity check
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        if (userStakes[msg.sender].isStaked) {
            revert StakingPeriodNotOver();
        }

        // Check zero transfer amount 
        if (msg.value <= 0) {
            revert CannotSendZeroValue();
        }

        // Check length of duration
        if (_duration > MAX_DURATION) {
            revert MaxDurationExceeded();
        }

        // Create new stake in memory for user
        Stake memory newStake;
        newStake.staker = msg.sender;
        newStake.stakeAmount = msg.value;
        newStake.startTime = block.timestamp;
        newStake.vestingPeriod = _duration;
        newStake.isStaked = true;

        // Add newly created stake to stakes mapping in storage
        userStakes[msg.sender] = newStake;

        // Trigger successful staking event
        emit StakeSuccessful(msg.sender, msg.value, block.timestamp);
    }

    function withdrawStake() external {
        // Perform sanity check
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        Stake storage st = userStakes[msg.sender];
        uint256 stakingPeriod = st.startTime + st.vestingPeriod;

        if (st.stakeAmount <= 0) {
            revert CannotSendZeroValue();
        }

        if (msg.sender != st.staker) {
            revert NotOwner();
        }

        if (block.timestamp < stakingPeriod) {
            revert StakingPeriodNotOver();
        }

        if (st.isMature) {
            revert StakingRewardsAlreadyClaimed();
        }

        st.stakeReward = _calculateReward(stakingPeriod);
        uint256 matureStake = st.stakeAmount + st.stakeReward;

        if (matureStake > address(this).balance) {
            revert InsufficientContractBalance();
        }

        st.isMature = true;
        st.isStaked = false;

        (bool success, ) = msg.sender.call{value: matureStake}("");
        if (!success) {
            revert FailedTransfer();
        }

        emit WithdrawSuccessful(msg.sender, matureStake, block.timestamp);
    }

    function _calculateReward(
        uint256 _duration
    ) private view returns (uint256) {
        Stake storage st = userStakes[msg.sender];
        uint256 principal = st.stakeAmount;
        uint256 stakingDuration = _duration;

        uint256 stakingReward = (principal * INTEREST_RATE * stakingDuration * PRECISION_FACTOR) /
            (SECONDS_IN_YEAR * 100 * PRECISION_FACTOR);

        return stakingReward;
    }

    function getMyStake() external view returns (Stake memory) {
        return userStakes[msg.sender];
    }

    function getUserStake(
        address _staker
    ) external view returns (Stake memory) {
        _onlyOwner();
        return userStakes[_staker];
    }

    function getUserRewardSoFar() external view returns (uint256) {
        Stake storage st = userStakes[msg.sender];
        uint256 timeVested = block.timestamp - st.startTime;

        uint256 reward = _calculateReward(timeVested);
        return reward;
    }

    function getTotalStakeAmount() external view returns (uint256) {
        _onlyOwner();
        return address(this).balance;
    }

    function _withdrawTokens() internal {
        _onlyOwner();

        uint256 contractBalance = address(this).balance;

        (bool success, ) = _owner.call{value: contractBalance}("");
        if (!success) {
            revert FailedTransfer();
        }
    }

    function _onlyOwner() private view {
        require(msg.sender == _owner);
    }

    receive() external payable {}
}
