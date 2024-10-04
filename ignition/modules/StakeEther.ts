import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const StakeEtherModule = buildModule("StakeEtherModule", (m) => {

    const stakeEther = m.contract("StakeEther");

    return { stakeEther };
});

export default StakeEtherModule;

// Deployed StakeEther: 
