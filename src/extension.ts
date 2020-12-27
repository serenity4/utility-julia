// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import { debug } from 'console'
import { exists, existsSync } from 'fs'
import { homedir } from 'os'
import { join } from 'path'
import { on } from 'process'
import * as vscode from 'vscode'
import * as net from 'net'
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient'
import * as process from 'process'
import { Server } from 'http'

// this method is called when your extension is activated
// your extension is activated the very first time the command is executed

var active_terminals = Array<vscode.Terminal>()
var srv = createREPLServer()

let client: LanguageClient

function selectJuliaServerPath() {
    let path = vscode.workspace.getConfiguration("julia").get("serverExecutable", "")
    return (path === "") ? selectJuliaPath() : path
}

function selectJuliaPath() {
    let path = vscode.workspace.getConfiguration("julia").get("executable", "")
    if (path === "") {
        let asdf_julia = join(homedir(), ".asdf", "shims", "julia")
        let paths = [asdf_julia, "/bin/julia", "/usr/bin/julia"]
        let i = 0
        while (path === "" || !existsSync(path)) {
            path = paths[i]
            i += 1
        }
    }
    if (path === "") {
        console.error("Could not find Julia executable")
    }
    return path
}

function addTerminal(term: vscode.Terminal) {
    active_terminals.push(term)
    debug("New active terminal", term)
}

function disposeTerminal(term: vscode.Terminal) {
    active_terminals.forEach((_term, index) => {
        if (_term === term) {
            active_terminals.splice(index, 1)
            term.dispose()
        }
    })
}

function selectREPLTerminal(focus: boolean = true): vscode.Terminal {
    var term = vscode.window.activeTerminal
    if (term) {
        if (!(active_terminals.includes(term))) {
            term = active_terminals.length > 0 ? active_terminals[active_terminals.length] : undefined
        }
    }
    if (!term) {
        term = startREPL(focus)
    }
    return term
}

function startREPL(focus: boolean = true): vscode.Terminal {
    debug("Starting new REPL.")
    const term = vscode.window.createTerminal("julia", selectJuliaPath(), ["-i", "--color=yes"])
    addTerminal(term)
    focus && vscode.commands.executeCommand("workbench.action.terminal.focusNext")
    return term
}

export function activate(context: vscode.ExtensionContext) {

    debug("Congratulations, your extension \"utility-julia\" is now active!")

    var disposables = [
        vscode.commands.registerCommand("utility-julia.start-repl", startREPL),
        vscode.commands.registerCommand("utility-julia.close-repls", () => {
            console.info("Closing all Julia REPLs.")
            active_terminals.forEach(term => {
                term.dispose()
            });
            active_terminals = []
        }),

        vscode.commands.registerCommand("utility-julia.eval-selection", () => {
            selectREPLTerminal(true)
            vscode.commands.executeCommand("workbench.action.terminal.runSelectedText")
        })]


    context.subscriptions.concat(disposables)

    // let language_client = startLanguageClient()
    // disposables.push(language_client.start())
}

function createREPLServer() {
    return net.createServer((sock) => {
        let pid = sock.read(8)
        debug("Received PID", pid)
        active_terminals.forEach(term => {
            term.processId.then((term_pid) => {
                if (term_pid === pid) {
                    disposeTerminal(term)
                }
            })
        });
    })
}

function startLanguageClient() {
    const server_jl = selectJuliaServerPath()
    const args = ["--color=yes"]
    const debug_args = args.concat([])
    const server_options = {
        run: { command: server_jl, args: args },
        debug: { command: server_jl, args: debug_args }
    }

    client = new LanguageClient("julia", "Julia Language Server (Utility)", server_options, {})
    client.registerProposedFeatures()

    return client
}

// this method is called when your extension is deactivated
export function deactivate() {
    return (!client) ? undefined : client.stop()
}
