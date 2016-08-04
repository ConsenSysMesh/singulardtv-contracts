from ethjsonrpc import EthJsonRpc
from ethereum.tester import languages
from ethereum.abi import ContractTranslator
from preprocessor import PreProcessor
import click
import time
import json


addresses = {}
abis = {}
pp = PreProcessor()


def wait_for_transaction_receipt(json_rpc, transaction_hash):
    while json_rpc.eth_getTransactionReceipt(transaction_hash)['result'] is None:
        print "Waiting for transaction receipt {}".format(transaction_hash)
        time.sleep(5)


def deploy_code(json_rpc, coinbase, file_path, construtor_params, contract_addresses, add_dev_code, contract_dir, gas, gas_price):
    if file_path not in addresses.keys():
        if contract_addresses:
            a_copy = addresses.copy()
            a_copy.update(contract_addresses)
            contract_addresses = a_copy
        else:
            contract_addresses = addresses
        language = "solidity" if file_path.endswith(".sol") else "serpent"
        code = pp.process(file_path, add_dev_code=add_dev_code, contract_dir=contract_dir, addresses=contract_addresses)
        # compile code
        combined = languages[language].combined(code)
        compiled_code = combined[-1][1]["bin_hex"]
        abi = combined[-1][1]["abi"]
        # replace library placeholders
        for library_name, library_address in contract_addresses.iteritems():
            compiled_code = compiled_code.replace("__{}{}".format(library_name, "_" * (38-len(library_name))), library_address[2:])
        if construtor_params:
            translator = ContractTranslator(abi)
            compiled_code += translator.encode_constructor_arguments(construtor_params).encode("hex")
        print 'Try to create contract with length {} based on code in file: {}'.format(len(compiled_code), file_path)
        transaction_hash = json_rpc.eth_sendTransaction(coinbase, data=compiled_code, gas=gas, gas_price=gas_price)["result"]
        wait_for_transaction_receipt(json_rpc, transaction_hash)
        contract_address = json_rpc.eth_getTransactionReceipt(transaction_hash)["result"]["contractAddress"]
        if json_rpc.eth_getCode(contract_address)["result"] == "0x":
            print 'Deploy of {} failed. Retry!'.format(file_path)
            deploy_code(json_rpc, coinbase, file_path, add_dev_code, contract_dir, gas, gas_price)
        contract_name = file_path.split("/")[-1].split(".")[0]
        addresses[contract_name] = contract_address
        abis[contract_name] = abi
        print 'Contract {} was created at address {}.'.format(file_path, contract_address)


def do_transaction(json_rpc, coinbase, contract, name, params, gas, gas_price):
    contract_address = addresses[contract] if contract in addresses else contract
    contract_abi = abis[contract]
    translator = ContractTranslator(contract_abi)
    data = translator.encode(name, [addresses[param] if param in addresses else param for param in params]).encode("hex")
    print 'Try to send {} transaction to contract {}.'.format(name, contract)
    transaction_hash = json_rpc.eth_sendTransaction(coinbase, to_address=contract_address, data=data, gas=gas, gas_price=gas_price)["result"]
    wait_for_transaction_receipt(json_rpc, transaction_hash)
    print 'Transaction {} for contract {} completed.'.format(name, contract)


@click.command()
@click.option('-f', help='File with instructions.')
@click.option('-host', default="localhost", help='Ethereum server host.')
@click.option('-port', default='8545', help='Ethereum server port.')
@click.option('-add_dev_code', default='false', help='Add admin methods.')
@click.option('-contract_dir', default='contracts/', help='Import directory.')
@click.option('-gas', default='4712388', help='Transaction gas.')
@click.option('-gas_price', default='50000000000', help='Transaction gas price.')
def setup(f, host, port, add_dev_code, contract_dir, gas, gas_price):
    with open(f) as data_file:
        instructions = json.load(data_file)
    json_rpc = EthJsonRpc(host, port)
    coinbase = json_rpc.eth_coinbase()["result"]
    print "Your coinbase: {}".format(coinbase)
    for instruction in instructions:
        print 'Your balance: {} Wei'.format(int(json_rpc.eth_getBalance(coinbase)['result'], 16))
        if instruction["type"] == "deployment":
            deploy_code(
                json_rpc,
                coinbase,
                instruction["file"],
                instruction["constructorParams"] if "constructorParams" in instruction else None,
                instruction["addresses"] if "addresses" in instruction else None,
                add_dev_code == "true",
                contract_dir,
                int(gas),
                int(gas_price)
            )
        elif instruction["type"] == "transaction":
            do_transaction(
                json_rpc,
                coinbase,
                instruction["contract"],
                instruction["name"],
                instruction["params"],
                int(gas),
                int(gas_price)
            )
    for contract_name, contract_address in addresses.iteritems():
        print 'Contract {} was created at address {}.'.format(contract_name, contract_address)

if __name__ == '__main__':
    setup()
