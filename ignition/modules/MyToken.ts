import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { ethers } from "ethers";

const name_ = "Web3CXI";
const symbol_ = "W3CXI";
const supply_ = ethers.parseUnits("1000000", 18);
const account_ = "0xd039E154e674986E1Ad2Eeb8c252755B7695cd34";


const W3CXIModule = buildModule("W3CXIModule", (m) => {
    const w3cxi = m.contract("W3CXI", [name_, symbol_, supply_, account_]);
    return { w3cxi };
});

export default W3CXIModule;

// Deployed W3CXI: 0x802Cd92D3777E6865017A250B33DDD61F94c1f24