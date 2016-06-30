from ethjsonrpc import EthJsonRpc
from ethereum.tester import languages
from preprocessor import PreProcessor
import click
import time


addresses = {}
pp = PreProcessor()


def wait_for_transaction_receipt(json_rpc, transaction_hash):
    while json_rpc.eth_getTransactionReceipt(transaction_hash)['result'] is None:
        print "Waiting for transaction receipt {}".format(transaction_hash)
        time.sleep(5)


def deploy_code(json_rpc, coinbase, file_path, add_dev_code, contract_dir, gas, gas_price):
    if file_path not in addresses.keys():
        language = "solidity" if file_path.endswith(".sol") else "serpent"
        code = pp.process(file_path, add_dev_code=add_dev_code, contract_dir=contract_dir, addresses=addresses)
        # compile code
        combined = languages[language].combined(code)
        compiled_code = combined[-1][1]["bin_hex"]
        # replace library placeholders
        for library_name, library_address in addresses.iteritems():
            compiled_code = compiled_code.replace("__{}{}".format(library_name, "_" * (38-len(library_name))), library_address[2:])
        print 'Try to create contract with length {} based on code in file: {}'.format(len(compiled_code), file_path)
        transaction_hash = json_rpc.eth_sendTransaction(coinbase, data=compiled_code, gas=gas, gas_price=gas_price)["result"]
        wait_for_transaction_receipt(json_rpc, transaction_hash)
        contract_address = json_rpc.eth_getTransactionReceipt(transaction_hash)["result"]["contractAddress"]
        if json_rpc.eth_getCode(contract_address)["result"] == "0x":
            print 'Deploy of {} failed. Retry!'.format(file_path)
            deploy_code(json_rpc, coinbase, file_path, add_dev_code, contract_dir, gas, gas_price)
        addresses[file_path.split("/")[-1].split(".")[0]] = contract_address
        print 'Contract {} was created at address {}.'.format(file_path, contract_address)


@click.command()
@click.option('-f', help='File with instructions.')
@click.option('-host', default="localhost", help='Ethereum server host.')
@click.option('-port', default='8545', help='Ethereum server port.')
@click.option('-add_dev_code', default='false', help='Add admin methods.')
@click.option('-contract_dir', default='contracts/', help='Import directory.')
@click.option('-gas', default='4712388', help='Transaction gas.')
@click.option('-gas_price', default='50000000000', help='Transaction gas price.')
def setup(f, host, port, add_dev_code, contract_dir, gas, gas_price):
    instructions = [line.strip().split('\t') for line in open(f) if line]
    json_rpc = EthJsonRpc(host, port)
    coinbase = json_rpc.eth_coinbase()["result"]
    print "Your coinbase: {}".format(coinbase)
    for instruction in instructions:
        if instruction[0].startswith('#'):
            continue
        print 'Your balance: {} Wei'.format(int(json_rpc.eth_getBalance(coinbase)['result'], 16))
        if instruction[0] == 'create':
            deploy_code(json_rpc, coinbase, instruction[1], add_dev_code == "true", contract_dir, int(gas), int(gas_price))
    for contract_name, contract_address in addresses.iteritems():
        print 'Contract {} was created at address {}.'.format(contract_name, contract_address)

if __name__ == '__main__':
    setup()
