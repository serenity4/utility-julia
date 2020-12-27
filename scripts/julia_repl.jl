using Sockets

# const port = ARGS[1]

port = 8000

const server = connect(5555)

atexit() do
    write(server, "End of session")
    close(server)
end
