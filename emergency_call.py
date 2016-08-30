from ethjsonrpc import EthJsonRpc
from ethereum.abi import ContractTranslator
from ethereum.transactions import Transaction
from ethereum.utils import privtoaddr
import click
import time
import json
import rlp


def wait_for_transaction_receipt(json_rpc, transaction_hash):
    while json_rpc.eth_getTransactionReceipt(transaction_hash)['result'] is None:
        print "Waiting for transaction receipt {}".format(transaction_hash)
        time.sleep(5)


@click.command()
@click.option('-host', default="localhost", help='Ethereum server host.')
@click.option('-port', default='8545', help='Ethereum server port.')
@click.option('-contract', default='cfeb869f69431e42cdb54a4f4f105c19c080a601', help='Crowdfund contract')
@click.option('-gas', default='4712388', help='Transaction gas.')
@click.option('-gas_price', default='50000000000', help='Transaction gas price.')
@click.option('-private_key', help='Private key as hex to sign transactions.')
def setup(host, port, contract, gas, gas_price, private_key):
    gas = int(gas)
    gas_price = int(gas_price)
    json_rpc = EthJsonRpc(host, port)
    coinbase = json_rpc.eth_coinbase()["result"]
    if private_key:
        print "Your address for your private key: {}".format(privtoaddr(private_key.decode('hex')).encode('hex'))
    else:
        print "Your coinbase: {}".format(coinbase)
    contract_abi = json.loads('[{"inputs": [], "constant": true, "type": "function", "name": "startDate", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "CROWDFUNDING_PERIOD", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": false, "type": "function", "name": "emergencyCall", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [{"type": "address", "name": "singularDTVFundAddress"}, {"type": "address", "name": "singularDTVTokenAddress"}], "constant": false, "type": "function", "name": "setup", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [], "constant": false, "type": "function", "name": "withdrawFunding", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "fundBalance", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "singularDTVFund", "outputs": [{"type": "address", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "baseValue", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "TOKEN_TARGET", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "singularDTVToken", "outputs": [{"type": "address", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "owner", "outputs": [{"type": "address", "name": ""}]}, {"inputs": [{"type": "uint256", "name": "valueInWei"}], "constant": false, "type": "function", "name": "changeBaseValue", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [{"type": "address", "name": ""}], "constant": true, "type": "function", "name": "investments", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": false, "type": "function", "name": "fund", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "stage", "outputs": [{"type": "uint8", "name": ""}]}, {"inputs": [], "constant": false, "type": "function", "name": "updateStage", "outputs": [{"type": "uint8", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "valuePerShare", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "TOKEN_LOCKING_PERIOD", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "campaignEndedSuccessfully", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "workshopWaited2Years", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [], "constant": true, "type": "function", "name": "CAP", "outputs": [{"type": "uint256", "name": ""}]}, {"inputs": [], "constant": false, "type": "function", "name": "withdrawForWorkshop", "outputs": [{"type": "bool", "name": ""}]}, {"inputs": [], "type": "constructor"}]')
    translator = ContractTranslator(contract_abi)
    data = translator.encode("emergencyCall", ()).encode("hex")
    bc_return_val = json_rpc.eth_call(to_address=contract, data=data)["result"]
    result_decoded = translator.decode("emergencyCall", bc_return_val[2:].decode("hex"))[0]
    if result_decoded:
        if private_key:
            address = privtoaddr(private_key.decode('hex'))
            nonce = int(json_rpc.eth_getTransactionCount('0x' + address.encode('hex'))["result"][2:], 16)
            tx = Transaction(nonce, gas_price, gas, contract, 0, data.decode('hex'))
            tx.sign(private_key.decode('hex'))
            raw_tx = rlp.encode(tx).encode('hex')
            transaction_hash = json_rpc.eth_sendRawTransaction("0x" + raw_tx)["result"]
        else:
            transaction_hash = json_rpc.eth_sendTransaction(coinbase, to_address=contract, data=data, gas=gas, gas_price=gas_price)["result"]
        wait_for_transaction_receipt(json_rpc, transaction_hash)
        print 'Transaction {} for contract {} completed.'.format("emergencyCall", contract)

if __name__ == '__main__':
    setup()
