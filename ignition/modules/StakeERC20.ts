import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const tokenAddress = "0x802Cd92D3777E6865017A250B33DDD61F94c1f24";

const StakeERC20Module = buildModule("StakeERC20Module", (m) => {

    const stakeErc20 = m.contract("StakeERC20", [tokenAddress]);

    return { stakeErc20 };
});

export default StakeERC20Module;


// Deployed StakeERC20: 
