import { ethers } from "hardhat";

const NASH_ESCROW_ADDRESS = "0x2eB8789CeE4fC77677150cac8eCD8137084b554B";
const CUSD_ADDRESS = "0xdE9e4C3ce781b4bA68120d6261cbad65ce0aB00b";
const CUSD_LABEL = "cUSD";

// 1e18 = 1 cUSD (18 decimals)
const ONE_CUSD = ethers.utils.parseUnits("1", 18);

const NASH_ESCROW_ABI = [
  "function initializeDepositTransaction(uint256 _amount, address _exchangeToken, string calldata _exchangeTokenLabel) external",
  "function initializeWithdrawalTransaction(uint256 _amount, address _exchangeToken, string calldata _exchangeTokenLabel) external",
  "function cancelTransaction(uint256 _transactionid) external",
  "function nextTransactionID() external view returns (uint256)",
  "function getTransactionByIndex(uint256 _transactionid) external view returns (tuple(uint256 id, uint256 amount, address clientAddress, address agentAddress, address exchangeToken, uint8 txType, uint8 status, bool agentApproval, bool clientApproval, string agentPaymentDetails, string clientPaymentDetails, string exchangeTokenLabel))",
];

const STATUS_LABELS = ["AWAITING_AGENT", "AWAITING_CONFIRMATIONS", "CONFIRMED", "CANCELED", "DONE"];
const TYPE_LABELS = ["DEPOSIT", "WITHDRAWAL"];

async function printTx(escrow: ethers.Contract, id: number) {
  const tx = await escrow.getTransactionByIndex(id);
  const amount = ethers.utils.formatUnits(tx.amount, 18);
  console.log(`  [${id}] ${TYPE_LABELS[tx.txType]} | ${amount} cUSD | ${STATUS_LABELS[tx.status]} | client: ${tx.clientAddress.slice(0, 10)}...`);
}

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Seeding with account:", deployer.address);

  const celoBalance = await deployer.getBalance();
  console.log("CELO balance:", ethers.utils.formatEther(celoBalance));

  const escrow = new ethers.Contract(NASH_ESCROW_ADDRESS, NASH_ESCROW_ABI, deployer);

  const startId = (await escrow.nextTransactionID()).toNumber();
  console.log(`\nStarting at transaction ID: ${startId}\n`);

  // --- Deposit transactions in varying amounts ---
  const depositAmounts = [
    ethers.utils.parseUnits("5", 18),
    ethers.utils.parseUnits("10", 18),
    ethers.utils.parseUnits("25", 18),
    ethers.utils.parseUnits("50", 18),
    ethers.utils.parseUnits("100", 18),
    ethers.utils.parseUnits("200", 18),
    ethers.utils.parseUnits("500", 18),
    ethers.utils.parseUnits("1000", 18),
  ];

  console.log("Creating deposit transactions...");
  const depositIds: number[] = [];
  for (const amount of depositAmounts) {
    const tx = await escrow.initializeDepositTransaction(amount, CUSD_ADDRESS, CUSD_LABEL);
    await tx.wait();
    const id = (await escrow.nextTransactionID()).toNumber() - 1;
    depositIds.push(id);
    console.log(`  Created deposit tx [${id}]: ${ethers.utils.formatUnits(amount, 18)} cUSD`);
  }

  // Cancel the last 3 deposits to get CANCELED state
  const toCancel = depositIds.slice(-3);
  console.log("\nCanceling 3 deposit transactions for CANCELED state...");
  for (const id of toCancel) {
    const tx = await escrow.cancelTransaction(id);
    await tx.wait();
    console.log(`  Canceled tx [${id}]`);
  }

  // --- Summary ---
  console.log("\n=== Seeded Transactions ===");
  const endId = (await escrow.nextTransactionID()).toNumber();
  for (let i = startId; i < endId; i++) {
    await printTx(escrow, i);
  }

  console.log(`\nDone. ${endId - startId} transactions created (IDs ${startId}–${endId - 1}).`);
  console.log(`Contract: ${NASH_ESCROW_ADDRESS}`);
  console.log(`cUSD:     ${CUSD_ADDRESS}`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
