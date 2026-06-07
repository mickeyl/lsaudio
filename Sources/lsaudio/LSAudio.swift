import ArgumentParser

@main
struct LSAudio: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "lsaudio",
        abstract: "List the processes that are currently playing or recording audio.",
        discussion: """
        Examples:
          lsaudio                  Processes currently playing or recording audio
          lsaudio --all            Every process registered with coreaudiod
          lsaudio --json           Machine-readable output
          lsaudio --watch          Live view, updated on audio activity changes
          lsaudio kill afplay      Send SIGTERM to active audio processes matching «afplay»
          lsaudio kill -s KILL 642 Send SIGKILL to PID 642

        Audio activity is read from coreaudiod's process objects \
        (CoreAudio process object API, macOS 14+).
        """,
        version: "1.0.0",
        subcommands: [List.self, Kill.self],
        defaultSubcommand: List.self
    )
}
