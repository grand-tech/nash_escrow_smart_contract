import { expect } from "chai";
import { BigNumber } from "ethers";
import {
  convertToNashTransactionObj,
  deployNashEscrowContract,
  NashEscrowTransaction,
} from "../utils/testutils";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";


describe("Withdrawal E2E", function () {
  it("Test end to end Withdrawal tx", async function () {
    const { owner, address2, tokenLabel, nashEscrow, USDc } = await loadFixture(
      deployNashEscrowContract
    );

    const agentSigner = address2;
    const clientSigner = owner;

    await USDc.approve(nashEscrow.address, 10);
    expect(await nashEscrow.nextTransactionID()).to.equal(0);

    let agentBalance = await USDc.balanceOf(agentSigner.address);
    let clientBalance = await USDc.balanceOf(clientSigner.address);

    // Initialize top up transaction.
    await expect(
      nashEscrow
        .connect(clientSigner)
        .initializeWithdrawalTransaction(5, USDc.address, tokenLabel)
    ).to.emit(nashEscrow, "TransactionInitEvent");

    // Check balances after method call.
    agentBalance = await USDc.balanceOf(agentSigner.address);
    clientBalance = await USDc.balanceOf(clientSigner.address);
    expect(clientBalance).to.equal(BigNumber.from("95"));
    expect(agentBalance).to.equal(BigNumber.from("0"));

    // Agent accept transaction
    await expect(
      nashEscrow
        .connect(agentSigner)
        .agentAcceptWithdrawalTransaction(0, "test phone number")
    ).to.emit(nashEscrow, "AgentPairingEvent");

    // Client write comment. i.e after comment encrypotion on the front end.
    await expect(
      nashEscrow
        .connect(clientSigner)
        .clientWritePaymentInformation(0, "test client number")
    ).to.emit(nashEscrow, "SavedClientCommentEvent");
    // Check balances after method call.
    agentBalance = await USDc.balanceOf(agentSigner.address);
    clientBalance = await USDc.balanceOf(clientSigner.address);
    expect(clientBalance).to.equal(BigNumber.from("95"));
    expect(agentBalance).to.equal(BigNumber.from("0"));

    // Client confirm transaction.
    expect(
      await nashEscrow.connect(clientSigner).clientConfirmPayment(0)
    ).to.emit(nashEscrow, "ConfirmationCompletedEvent");

    // Check balances after method call.
    agentBalance = await USDc.balanceOf(agentSigner.address);
    clientBalance = await USDc.balanceOf(clientSigner.address);
    expect(agentBalance).to.equal(BigNumber.from("0"));
    expect(clientBalance).to.equal(BigNumber.from("95"));

    // Agent confirm transaction.
    expect(
      await nashEscrow.connect(agentSigner).agentConfirmPayment(0)
    ).to.emit(nashEscrow, "TransactionCompletionEvent");

    // Check balances after method call.
    agentBalance = await USDc.balanceOf(agentSigner.address);
    clientBalance = await USDc.balanceOf(clientSigner.address);
    expect(agentBalance).to.equal(BigNumber.from("5"));
    expect(clientBalance).to.equal(BigNumber.from("95"));

    // Value above next tx index
    const tx2: NashEscrowTransaction = convertToNashTransactionObj(
      await nashEscrow.connect(address2).getTransactionByIndex(0)
    );
    expect(tx2.id).equal(0);
    expect(tx2.status).equal(4);
  });
});
