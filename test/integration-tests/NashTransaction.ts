import { expect } from "chai";
import { BigNumber } from "ethers";
import { TestUtil, NashEscrowTransaction } from "../testutils";

describe("Deposit E2E", function () {
  it("Test end to end Deposit tx", async function () {
    const testUtil = new TestUtil();
    await testUtil.intit();

    const agentSigner = testUtil.user1Address;
    const clientSigner = testUtil.user2Address;

    const agentAddress = await agentSigner.getAddress();
    const clientAddress = await clientSigner.getAddress();

    await testUtil.cUSD.approve(testUtil.nashEscrow.address, 10);
    expect(await testUtil.nashEscrow.getNextTransactionIndex()).to.equal(0);

    let agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    let clientBalance = await testUtil.cUSD.balanceOf(clientAddress);

    // Initialize top up transaction.
    expect(
      await testUtil.nashEscrow
        .connect(clientSigner)
        .initializeDepositTransaction(
        5,
        testUtil.cUSD.address
      )
    )
      .to.emit("NashEscrow", "TransactionInitEvent")
      .withArgs(0, testUtil.user1Address.getAddress());

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(agentBalance).to.equal(BigNumber.from("100"));
    expect(clientBalance).to.equal(BigNumber.from("0"));

    // Agent accept transaction
    expect(
      await testUtil.nashEscrow
        .connect(agentSigner)
        .agentAcceptDepositTransaction(0, "test phone number")
    )
      .to.emit("NashEscrow", "AgentPairingEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Client write comment. i.e after comment encrypotion on the front end.
    expect(
      await testUtil.nashEscrow
        .connect(clientSigner)
        .clientWritePaymentInformation(0, "test client number")
    )
      .to.emit("NashEscrow", "SavedClientCommentEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );
    ;
    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(agentBalance).to.equal(BigNumber.from("95"));
    expect(clientBalance).to.equal(BigNumber.from("0"));

    // Client confirm transaction.
    expect(
      await testUtil.nashEscrow.connect(clientSigner).clientConfirmPayment(0)
    )
      .to.emit("NashEscrow", "ConfirmationCompletedEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(agentBalance).to.equal(BigNumber.from("95"));
    expect(clientBalance).to.equal(BigNumber.from("0"));

    // Agent confirm transaction.
    expect(
      await testUtil.nashEscrow.connect(agentSigner).agentConfirmPayment(0)
    )
      .to.emit("NashEscrow", "TransactionCompletionEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    const nashTreasury = await testUtil.cUSD.balanceOf(
      testUtil.nashTreasury.address
    );
    expect(nashTreasury).to.equal(BigNumber.from("1"));
    expect(agentBalance).to.equal(BigNumber.from("97"));
    expect(clientBalance).to.equal(BigNumber.from("2"));

    // Value above next tx index
    const tx2: NashEscrowTransaction = testUtil.convertToNashTransactionObj(
      await testUtil.nashEscrow
        .connect(testUtil.user2Address)
        .getTransactionByIndex(0)
    );
    expect(tx2.id).equal(0);
    expect(tx2.status).equal(4);
  });
});



describe("Withdrawal E2E", function () {
  it("Test end to end Withdrawal tx", async function () {
    const testUtil = new TestUtil();
    await testUtil.intit();

    const agentSigner = testUtil.user2Address;
    const clientSigner = testUtil.user1Address;

    const agentAddress = await agentSigner.getAddress();
    const clientAddress = await clientSigner.getAddress();

    await testUtil.cUSD.approve(testUtil.nashEscrow.address, 10);
    expect(await testUtil.nashEscrow.getNextTransactionIndex()).to.equal(0);

    let agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    let clientBalance = await testUtil.cUSD.balanceOf(clientAddress);

    // Initialize top up transaction.
    expect(
      await testUtil.nashEscrow
        .connect(clientSigner)
        .initializeWithdrawalTransaction(
        5,
        testUtil.cUSD.address
      )
    )
      .to.emit("NashEscrow", "TransactionInitEvent")
      .withArgs(0, testUtil.user1Address.getAddress());

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(clientBalance).to.equal(BigNumber.from("95"));
    expect(agentBalance).to.equal(BigNumber.from("0"));

    // Agent accept transaction
    expect(
      await testUtil.nashEscrow
        .connect(agentSigner)
        .agentAcceptWithdrawalTransaction(0, "test phone number")
    )
      .to.emit("NashEscrow", "AgentPairingEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Client write comment. i.e after comment encrypotion on the front end.
    expect(
      await testUtil.nashEscrow
        .connect(clientSigner)
        .clientWritePaymentInformation(0, "test client number")
    )
      .to.emit("NashEscrow", "SavedClientCommentEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );
    ;
    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(clientBalance).to.equal(BigNumber.from("95"));
    expect(agentBalance).to.equal(BigNumber.from("0"));

    // Client confirm transaction.
    expect(
      await testUtil.nashEscrow.connect(clientSigner).clientConfirmPayment(0)
    )
      .to.emit("NashEscrow", "ConfirmationCompletedEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    expect(agentBalance).to.equal(BigNumber.from("0"));
    expect(clientBalance).to.equal(BigNumber.from("95"));

    // Agent confirm transaction.
    expect(
      await testUtil.nashEscrow.connect(agentSigner).agentConfirmPayment(0)
    )
      .to.emit("NashEscrow", "TransactionCompletionEvent")
      .withArgs(
        0,
        testUtil.user1Address.getAddress(),
        testUtil.user2Address.getAddress()
      );

    // Check balances after method call.
    agentBalance = await testUtil.cUSD.balanceOf(agentAddress);
    clientBalance = await testUtil.cUSD.balanceOf(clientAddress);
    const nashTreasury = await testUtil.cUSD.balanceOf(
      testUtil.nashTreasury.address
    );
    expect(nashTreasury).to.equal(BigNumber.from("1"));
    expect(agentBalance).to.equal(BigNumber.from("4"));
    expect(clientBalance).to.equal(BigNumber.from("95"));

    // Value above next tx index
    const tx2: NashEscrowTransaction = testUtil.convertToNashTransactionObj(
      await testUtil.nashEscrow
        .connect(testUtil.user2Address)
        .getTransactionByIndex(0)
    );
    expect(tx2.id).equal(0);
    expect(tx2.status).equal(4);
  });
});
