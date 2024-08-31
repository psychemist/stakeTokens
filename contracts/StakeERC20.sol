// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.24;

import "./IERC20.sol";

contract StakeERC20 {
    // Custom Errors
    error ZeroAddressDetected();
    error CannotSendZeroValue();
    error InsufficientContractBalance();
    error InsufficientFunds();
    error MaxDurationExceeded();
    error StakingPeriodNotOver();
    error StakingRewardsAlreadyClaimed();
    error NotOwner();

    address private _owner;
    IERC20 public token;

    uint256 public constant MAX_DURATION = 365 days;
    uint256 public constant SECONDS_IN_YEAR = MAX_DURATION * 24 * 60 * 60;
    // uint64 public constant PRECISION_FACTOR = 1e18; // Scaling factor for precision
    uint8 public constant INTEREST_RATE = 4; // Representing 4% as4

    struct Stake {
        uint256 stakeAmount; // in lowest denomination (1e18)
        uint256 stakeReward; // in lowest denomination (1e18)
        uint256 startTime; // in seconds
        uint256 vestingPeriod; // in seconds
        address staker;
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
        address indexed staker,
        uint256 amount,
        uint256 timeAtWithdrawal
    );

    constructor(address _tokenAddress) {
        _owner = msg.sender;
        token = IERC20(_tokenAddress);
    }

    function stakeTokens(uint256 _amount, uint256 _duration) external {
        // Perform checks
        if (msg.sender == address(0)) {
            revert ZeroAddressDetected();
        }

        if (_amount <= 0) {
            revert CannotSendZeroValue();
        }

        if (_duration > MAX_DURATION) {
            revert MaxDurationExceeded();
        }

        // Create new stake variable in memory for user
        Stake memory newStake;

        newStake.staker = msg.sender;
        newStake.stakeAmount = _amount;
        newStake.startTime = block.timestamp;
        newStake.vestingPeriod = _duration;

        // Deposit tokens into contract staking pool
        if (token.balanceOf(msg.sender) < _amount) {
            revert InsufficientFunds();
        }

        // Push newly created stake to stakes array in storage
        userStakes[msg.sender] = newStake;

        // Stake user'sapproved token amount
        token.transferFrom(msg.sender, address(this), _amount);

        // Trigger staking event
        emit StakeSuccessful(msg.sender, _amount, block.timestamp);
    }

    function withdrawStake() external {
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

        if (matureStake > token.balanceOf(address(this))) {
            revert InsufficientContractBalance();
        }

        st.isMature = true;

        token.transfer(msg.sender, matureStake);

        emit WithdrawSuccessful(msg.sender, matureStake, block.timestamp);
    }

    function _calculateReward(
        uint256 _duration
    ) private view returns (uint256) {
        Stake storage st = userStakes[msg.sender];
        uint256 principal = st.stakeAmount;
        uint256 stakingDuration = _duration;

        uint256 stakingReward = (principal * INTEREST_RATE * stakingDuration) /
            (SECONDS_IN_YEAR * 100);

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
        return token.balanceOf(address(this));
    }

    function _onlyOwner() private view {
        require(msg.sender == _owner);
    }
}
