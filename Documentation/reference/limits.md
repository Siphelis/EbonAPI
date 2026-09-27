# Limits

Every size, count and delay a developer may run into, in one place. Sizes are in bytes.

## Names

| | Limit |
| --- | --- |
| Addon name | 1 to 32 characters, `A-Z a-z 0-9 _` |
| Dataset name | 1 to 32 characters, `A-Z a-z 0-9 _` |
| Channel op, whisper stream op | letters and digits |
| Version text | 20 characters |

## Sending

| | Limit |
| --- | --- |
| Queue pace | one line every 0.15 seconds, shared by every addon |
| Player queue | 500 lines; server messages are never refused |
| Offline hold | 60 seconds without whispers to a player reported not found |

## Server

| | Limit |
| --- | --- |
| Outgoing message, opcode and body | 240 bytes |
| Incoming message | 400 parts, complete within 20 seconds |

## Channel

| | Limit |
| --- | --- |
| Packets per body | 16 |
| Body | about 3,600 bytes with short names; the error message gives the exact figure |
| Reassembly | 30 seconds |

## Whispers

| | Limit |
| --- | --- |
| Plain whisper | 255 bytes minus the prefix and one separator |
| Stream | 400 parts, about 90 KB with short prefix, op and id |
| Reassembly | 30 seconds between parts |

## Sharing

| | Limit |
| --- | --- |
| Text | 32,768 bytes |
| State | whole number from 0 to 9,007,199,254,740,991 |
| Announce | 2 seconds after joining, 15 seconds after a change, manual once every 30 seconds |
| Rounds | every 2 minutes, one peer at random |
| Peer memory | 10 minutes |
| Fetch timeout | 30 seconds |
| Same request to the same peer | once every 10 seconds |

## Echo profile

| | Limit |
| --- | --- |
| Slots | 1 to 20 |
| Echoes per build | 150, stacks up to 63 |
| Ban lists | 20 lists of 150 echoes |
| Echo spell ids | 200000 to 204095 |
| Build list request | 10 seconds after a new session |

## Sessions and diagnostics

| | Limit |
| --- | --- |
| New session | after 10 minutes away |
| Update notice | once per session and per version |
| Trace | the last 128 entries |
| Performance reports kept | 20 per addon |
