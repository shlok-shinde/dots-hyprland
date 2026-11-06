"""Hermes for the sidebar: attach to the profile's gateway and relay it over stdio.

Hermes no longer lets a UI run its own gateway beside the shared one ("refused:
~/.hermes is owned by a running gateway; attach to it instead"): its terminal
and desktop apps attach to the profile's gateway over a WebSocket. This does
the same, the way Hermes' own terminal app does (ui-tui/scripts/gateway_bootstrap.py:
start the gateway if none runs, get a ticket, connect), and relays the socket
as the newline JSON-RPC the sidebar (services/Hermes.qml) speaks: one frame
per line each way.

    <hermes python> -I hermes-bridge.py <hermes source root>

The python is the installation's own (`hermes --print-runtime-command`): it
has Hermes' dependencies, websockets among them. Exits 0 when the sidebar
closes stdin, 1 with a one-line reason on stderr when the gateway can't be
reached or drops the connection.
"""
import asyncio
import contextlib
import importlib.util
import os
import sys


def fail(reason: str) -> None:
    print(" ".join(line.strip() for line in str(reason).splitlines() if line.strip()) or "unknown error",
          file=sys.stderr, flush=True)
    sys.exit(1)


def grant(root: str) -> dict:
    os.environ["HERMES_PYTHON_SRC_ROOT"] = root
    sys.path.insert(0, root)
    path = os.path.join(root, "ui-tui", "scripts", "gateway_bootstrap.py")
    if not os.path.isfile(path):
        fail(f"this Hermes has no {path}: update Hermes")
    spec = importlib.util.spec_from_file_location("hermes_gateway_bootstrap", path)
    bootstrap = importlib.util.module_from_spec(spec)
    try:
        with contextlib.redirect_stdout(sys.stderr):  # stdout is the sidebar's channel
            spec.loader.exec_module(bootstrap)
            return bootstrap.bootstrap(True)  # start the gateway when none runs
    except Exception as exc:  # what Hermes' own TUI shows: its verdict and remedy
        fail(f"can't reach the Hermes gateway: {exc}")


async def relay(url: str, protocols: list) -> int:
    from websockets.asyncio.client import connect
    from websockets.exceptions import ConnectionClosed

    loop = asyncio.get_running_loop()
    stdin = asyncio.StreamReader(limit=64 * 1024 * 1024)
    await loop.connect_read_pipe(lambda: asyncio.StreamReaderProtocol(stdin), sys.stdin)

    # The gateway is on this machine: no keepalive pings (an idle chat must not time out)
    async with connect(url, subprotocols=protocols, max_size=None, ping_interval=None) as ws:
        async def upstream():
            while line := await stdin.readline():
                if line.strip():
                    await ws.send(line.decode().strip())
            return 0  # the sidebar let go

        async def downstream():
            try:
                async for frame in ws:
                    text = frame if isinstance(frame, str) else frame.decode()
                    sys.stdout.write(text.strip() + "\n")
                    sys.stdout.flush()
            except ConnectionClosed:
                pass
            print(f"the Hermes gateway closed the connection ({ws.close_code})", file=sys.stderr, flush=True)
            return 1

        tasks = [asyncio.create_task(upstream()), asyncio.create_task(downstream())]
        done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for task in pending:
            task.cancel()
        return done.pop().result()


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: hermes-bridge.py <hermes source root>")
    target = grant(sys.argv[1])
    try:
        code = asyncio.run(relay(target["url"], target["protocols"]))
    except (OSError, ImportError) as exc:
        fail(f"can't connect to the Hermes gateway: {exc}")
    sys.exit(code)


if __name__ == "__main__":
    main()
