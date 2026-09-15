# Stopping a Stream: A Static Stream File Format That Records Like Tape and Plays Like a Broadcast

*Lab Report — IEEE Format*

<!-- SPDX-License-Identifier: MIT -->
Copyright (c) 2026 Paul Richeson. MIT licensed — see `LICENSE`. Copal Linux is
an aggregation of Alpine Linux, not a derivative work of it; Alpine and its
packages remain under their own licences.

---

## Abstract

Light can be slowed until it seems to stand still, and then released. What
the experiments actually keep is not moving light but the pulse's state,
written into matter and read back out as light [1]–[6]. This report takes
that as the model for a *static stream*: a stream written into a file with
its order, its pace and its tolerance for damage intact, so that it can later
be let go again as a stream. It surveys the technologies that already do
parts of this: the VCR and the hard-disk time-shift buffer, VideoLAN's
server and client, transport streams built for noisy channels,
Reed–Solomon and fountain codes, chained and sealed logs, streaming
authenticated encryption, and serial-line file transfer. It then specifies a
version-0 format, `.sstr`, and a prototype, `tools/copal-sstr.py`, in the
Python standard library with `ssh-keygen` as its only outside program.

The interface is two verbs. `record` freezes a stream, or compresses a file.
`play` lets it go: into a new file, to a player on stdout at the pace of
capture, or served over HTTP to VLC or mpv as clients. Payload bytes are
never decoded, so no codec is involved. Each record is protected by
RS(255,223), interleaved, and each group of 16 data records by an XOR parity
record, which is 21.5 % redundancy by design and 22.4 % as measured on full
records. Checkpoints are signed with the user's SSH key; nothing is
encrypted. An armor layer turns any `.sstr` into CRC-checked base64url lines
of at most 80 columns for a tty, RS-232 line or COM port. Lines lost on the
wire become erasures, which the Reed–Solomon decoder corrects at twice the
rate of unknown errors.

Measured on an aarch64 Alpine guest:
- **Live capture:** a 20-second live MPEG-TS was recorded while another
  process played it back. Both copies were byte-identical to what ffmpeg
  emitted, and paced playback took 19.48 s.
- **Clients:** mpv and VLC decoded the capture served by `play --serve`.
- **Damage:** a signed 4 MB capture came back byte-identical after bit errors
  up to 3 in 1,000, a wiped record in each of two groups, or the loss of its
  stream header. Truncated, it verified up to its last checkpoint. A record
  forged with valid CRCs and parity was caught by its signed checkpoint.
- **Serial line:** over a pty at 115200 baud the armor carried 4,500 payload
  bytes/s. It survived 5 % of lines dropped, and 1 corrupted bit in 10,000
  with console chatter mixed in; it failed from 8 %.

Section VI sets out the limits:
- The XOR outer code rebuilds only one record per group.
- Its cost grows with uneven record sizes.
- Interleaving within a record is too shallow for a lossy serial line.
- A capture format settles nothing about whether a stream may be kept.

## I. Objective

1. Define a *static stream* precisely enough to build: a stream stopped in a
   medium and released again with its order and timing.
2. Describe, in IEEE style, the prior technologies it borrows from: tape and
   time-shift recording, server/client stream buffers, damage-tolerant
   containers, error-correcting codes, chaining and sealing, and serial-line
   transfer.
3. Answer the question behind the design: is a block cipher with an IV and a
   seed, appended to, a stream? What should a format keep from that idea
   without encrypting?
4. Specify a file format that a stream can be written into as it arrives, and
   read out of as a stream. It must not depend on a codec, and it should
   compress when the input is a file.
5. Give it about 20 % redundancy for bit-error correction.
6. Sign it with the user's own private key, without encrypting it.
7. Provide the simple interface of *record* (compress) and *play* (expand).
   Play should expand into the filesystem, feed a player, or serve clients in
   the manner of VideoLAN's server and client.
8. Provide a layer that carries the format over a tty: base64 blocks suited
   to RS-232 or a COM port.
9. Build a prototype and measure it: fidelity, overhead, pace, damage, and
   the serial path.

## II. Background: What Already Exists

### A. Stopped light, the analogy

Hau, Harris, Dutton and Behroozi slowed light to 17 m/s in an ultracold
sodium gas cooled below the Bose–Einstein transition, using electromagnetically
induced transparency (EIT) [1]. In 2001 two groups stopped it:
- **Cold sodium:** a light pulse was held for up to about 1 ms and released
  by switching the coupling laser back on [2].
- **Warm rubidium vapour:** the same effect, in a far simpler medium [3].

The mechanism is what makes the analogy useful. The pulse's excitation is
"reversibly mapped into a Zeeman (spin) coherence" [3], a dark-state
polariton whose shape and quantum state pass into "metastable collective
states of matter" [4]. Nothing moves slowly; the information is written into
the medium and read back out.

The holding time has grown since:
- **2013:** EIT storage beyond 40 s, and images stored for a minute, in a
  praseodymium-doped crystal (Pr³⁺:Y₂SiO₅) [5].
- **2021:** one hour of coherent optical storage in an atomic frequency comb
  memory in ¹⁵¹Eu³⁺:Y₂SiO₅ [6].

A static stream in software is the same move. The stream's bytes, order and
timing are written into a file as they arrive, then re-emitted as a stream.
Like stopped light, it keeps the state faithfully only if the medium
protects it.

### B. Recording what was broadcast

The consumer VCR made broadcast into an object:
- **Recorders:** Sony's Betamax went on sale in Japan in May 1975 and JVC's
  VHS (HR-3300) in September 1976 [7].
- **The law:** in *Sony Corp. of America v. Universal City Studios*
  (1984) the U.S. Supreme Court held, 5–4, that private, noncommercial
  time-shifting of free broadcast television is fair use [8].
- **The time-shift buffer:** in 1999 TiVo and ReplayTV put a hard disk behind
  the tuner that recorded continuously, which let a viewer pause and rewind
  live television [12].

A tape keeps order and pace. A time-shift buffer adds reading while writing.
`.sstr` needs both.

### C. The server and the client

VideoLAN began in 1996 as a student project at École Centrale Paris. VLC
stood for *VideoLAN Client*, paired with *VideoLAN Server* (VLS). VLS was
later largely subsumed into VLC; no source dates that. The code went under
the GPL on 1 February 2001 [9].

VLC still has both halves:
- **Stream output:** `--sout '#std{access=file,mux=ts,dst=…}'` sends a stream
  to a file or network.
- **Dump:** the demuxer `--demux=dump --demuxdump-file=…` writes an incoming
  stream without decoding it.
- **Timeshift:** built into the core as `--input-timeshift-path` and
  `--input-timeshift-granularity` [10].

Other tools do the same without re-encoding. mpv's
`--stream-record=<file>` writes what its demuxer reads, and ffmpeg's
`-c copy` copies streams untouched into, for example, an `mpegts` file [11].

### D. Containers built to be damaged

- **MPEG-2 Transport Stream** (ITU-T H.222.0 | ISO/IEC 13818-1) [13] carries
  programs in 188-byte packets. Each starts with the sync byte 0x47 and
  carries a 13-bit PID and a 4-bit continuity counter, so a receiver can find
  its place again after loss.
- **DVB-S** (ETSI EN 300 421) [14] protects every packet with a shortened
  RS(204,188) code, from RS(255,239) with T = 8, which corrects 8 bytes per
  packet. It adds a Forney convolutional interleaver of depth 12 and an inner
  punctured convolutional code. That is two error-correcting codes and an
  interleaver, sized for a broadcast channel.
- **Ogg** (RFC 3533) [15] frames streams in pages beginning `OggS`, each with
  a CRC-32.
- **pcapng** [16], still an IETF Internet-Draft, stores timestamped packet
  captures in blocks.
- **asciicast** [17] stores a terminal session as a JSON header and
  `[time, code, data]` events. Version 3 counts time from the previous event.
- **WARC** (ISO 28500:2017) [18] is how web archives keep HTTP request and
  response records.

### E. Archives read like tape

- **tar** [19] is the *tape archive*: 512-byte blocks read in order, which
  is why `tar c | … | tar x` works as a pipe.
- **zstd** (RFC 8878) [20] compresses as a stream of frames, and its contrib
  *seekable format* adds a seek table over independent frames.
- **xz** [21] has blocks and an index, which allow random access when a
  file was written with more than one block.

### F. Error correction

A Reed–Solomon code with n − k parity symbols corrects e errors at unknown
places and f erasures at known places as long as 2e + f ≤ n − k [22].

| Scheme | Code and structure | What it corrects |
|---|---|---|
| CCSDS 131.0-B-5 [23] (space links) | RS(255,223), E = 16, interleaving depth I = 1, 2, 3, 4, 5 or 8 | 16 symbols per codeword |
| QR codes [24] | levels L, M, Q and H | about 7, 15, 25 and 30 % of codewords |
| PAR2 [25] | Reed–Solomon over GF(2¹⁶); `par2 create -r<n>` sets redundancy in percent | any lost file blocks up to the redundancy chosen |
| SMPTE ST 2022-1 [26] (video over IP) | XOR parity over an L-column × D-row packet matrix | one packet per row or column |
| RaptorQ (RFC 6330) [27], after Luby's LT codes [28] | systematic fountain code: the sender can make as many repair symbols as it likes | the source, from almost any set of received symbols slightly larger than it |

The SMPTE matrix is the one that lands on this report's figure. Its 2-D
overhead is (L + D)/(L × D), so L = D = 10 is exactly 20 %.

### G. Chaining, sealing and signing

NIST SP 800-38A [29] defines the modes that turn a block cipher such as AES
into something that runs over a stream:
- **CBC** chains every block to the ciphertext before it, starting from an IV.
- **CTR** encrypts a counter that starts from a nonce, producing a keystream.

Newer designs make streaming authenticated encryption explicit:
- **age** [30] splits a payload into 64 KiB chunks under ChaCha20-Poly1305.
  It uses the STREAM construction of Hoang, Reyhanitabar, Rogaway and
  Vizár [31], with a nonce counter whose last byte marks the final chunk,
  so truncation is detected.
- **libsodium** `crypto_secretstream` [32] has a `TAG_FINAL` for the same
  purpose.

Integrity without encryption has its own line:
- **journald:** Forward Secure Sealing seals a log with a key that changes
  at an interval, 15 minutes by default [33].
- **Certificate Transparency:** RFC 6962, since replaced by RFC 9162 [34],
  keeps an append-only Merkle tree with signed tree heads.
- **BitTorrent v2** (BEP 52) [35] hashes every file as a SHA-256 Merkle tree
  of 16 KiB blocks.
- **OpenSSH 8.1** (October 2019) [36] added `ssh-keygen -Y sign` and
  `-Y verify`, which sign arbitrary data with an existing SSH key under a
  namespace and verify against an `allowed_signers` list.
- **CRC-32C** (Castagnoli), used in iSCSI, ext4 and Btrfs [37], catches
  accidental damage cheaply.

### H. Bytes over a serial line

- **Text encodings:** base64 and base64url are RFC 4648 [38]. MIME caps
  base64 lines at 76 characters [39]. uuencode came from Mary Ann Horton at
  Berkeley in 1980 [40], and Ascii85 is the PostScript and PDF filter [38].
- **Transfer protocols:**
  - **XMODEM** (Ward Christensen, 1977) sent 128-byte blocks with an 8-bit
    checksum, later a CRC-16.
  - **YMODEM** used 1 K blocks.
  - **ZMODEM** (Forsberg, 1986) streamed with a 32-bit CRC [41].
  - **Kermit** began at Columbia University in 1981 [42].
- **Line records:** Intel HEX puts an address and a checksum on every ASCII
  line [43].
- **Framing:** SLIP (RFC 1055) [44] and COBS [45] frame packets on a raw
  byte line.
- **Line rate and flow control:** 8N1 framing spends 10 bits per byte, so
  115200 baud is 11,520 bytes/s, and XON and XOFF are the bytes 0x11 and
  0x13 [46].
- **File signatures:** PNG's opens with a byte that has its high bit set,
  then CR-LF, ^Z and LF, to catch transfers that strip bit 7 or alter line
  endings [47].

### I. Archival practice

The OAIS reference model (ISO 14721:2025) [48] and BagIt (RFC 8493) [49]
both make *fixity* the core of preservation: a stored object comes with a
digest to check it against.

## III. Design: the Static Stream Format, Version 0

### A. Principles

1. **Order and time are content.** Every record carries the time its first
   byte arrived, so playback can keep the original pace or ignore it.
2. **Write once, in order, never go back.** A file that is still being
   written is a valid prefix, and can be played while it grows.
3. **Bytes, not codecs.** The payload is opaque and labelled with a MIME
   type; only the eventual player decodes.
4. **Find your place again.** Every record starts with a sync marker and a
   header that can be repaired, so a reader resynchronises after any loss,
   as a transport stream does.
5. **Detect, correct, then prove.** CRCs detect damage and Reed–Solomon
   corrects it. Parity rebuilds what is lost, and signed checkpoints prove
   what remains is what was recorded.
6. **Signed, not encrypted.**

### B. Layout

```
file      = signature record*
signature = 89 53 53 54 0D 0A 1A 0A            "\x89SST\r\n\x1a\n", after PNG
record    = header-copy-A header-copy-B body
header-copy-A = A7 53 53 52  hdr32  rs32       sync "\xa7SSR" + RS(64,32) codeword
header-copy-B = A7 53 53 72  hdr32  rs32       sync "\xa7SSr", the same codeword again
hdr32     = type u8 | flags u8 | reserved u16 | seq u64 | t_us u64
            | plain_len u32 | body_crc u32 | hdr_crc u32         (little-endian)
body      = interleaved RS(255,223) codewords of the plain body
```

A record header is 136 bytes on disk. The body's length follows from
`plain_len` alone. With `full, rest = divmod(plain_len, 223)`, it is
`255 × full + (rest + 32 if rest else 0)`. The last codeword is shortened,
so nothing about the body needs storing.

| Type | Body | Written | In checkpoints |
|---|---|---|---|
| `H` stream header | JSON: stream id, content type, created, chunk and alignment, FEC and checkpoint settings, public key, and optional source, license and note | twice | yes |
| `D` data | payload bytes, or a deflate stream when flag 1 is set | once | yes |
| `P` parity | count, then (seq, t_us, flags, length, CRC) for each data record of its group, then the XOR of their bodies | once | no |
| `C` checkpoint | JSON: previous digest, `[seq, SHA-256]` entries, digest, SSH signature, and the stream header again | twice | chained |
| `E` end | JSON: data records, payload bytes and payload SHA-256, and whether the writer was interrupted | twice | yes |

### C. The inner code

Every plain body is cut into 223-byte pieces, each given 32 parity bytes. The
parameters are those of CCSDS [23], though the field basis differs:
GF(2⁸) with polynomial 0x11d and first root α⁰. The codewords are then
interleaved byte by byte: all first bytes, then all second bytes, and so on.
A 64 KiB record has 294 codewords, so a burst of B bytes puts about B/294
bytes into each of them.

The header is one small codeword that is not interleaved, so it is written
twice with different sync markers. A burst that ruins one copy leaves the
other. When both are partly erased, the reader merges them byte by byte
before decoding.

On a clean read the reader checks only the CRC-32 of the systematic bytes,
and runs the decoder only when that fails.

### D. The outer code

After every G = 16 data records (fewer at a checkpoint or the end), a parity
record lists their sequence numbers, times, flags, lengths and CRCs, and
holds the XOR of their bodies padded to the longest. Any one record of the
group lost outright can be rebuilt. The redundancy by design, for full
records, is

  (1 + 32/223) × (1 + 1/16) = 1.1435 × 1.0625 = **1.215**,

plus 136 bytes per record header and the small H, C and E records.

### E. Checkpoints and signing

A checkpoint is written after every 64 hashed records or 10 seconds, always
straight after a parity record, and at the end. Its digest is

  D₀ = SHA-256("sstr-v0 genesis" ‖ stream_id)
  Dₙ = SHA-256("sstr-v0 checkpoint" ‖ Dₙ₋₁ ‖ seq₁ ‖ h₁ ‖ … ‖ seqₘ ‖ hₘ)

where each hᵢ is the SHA-256 of a record's 28 header bytes and plain body.
Only H, D and E records are hashed. With `--key`, the writer signs
"sstr-v0 " ‖ stream_id ‖ Dₙ with `ssh-keygen -Y sign -n sstr@copal`. That
works with an unencrypted Ed25519 key or with a public key whose private
half is held by `ssh-agent`. The public key sits in the stream header.

Four properties follow from the entry list:
- One damaged record fails only its own entry.
- A truncated capture verifies up to its last checkpoint.
- The chain of digests shows when a checkpoint is missing.
- Each checkpoint repeats the stream header, as a transport stream repeats
  its program tables, so a reader that lost the header, or joined late,
  still learns the key and the content type.

The reader checks each signature against the header's key through a
one-line temporary `allowed_signers` file. With `--allowed-signers FILE` it
also names the principal, or exits 1 when the key is not listed.

### F. Timing and cutting

`record` reads its input as a stream:
- **Chunking:** a data record is emitted when `--chunk` bytes (64 KiB) have
  arrived, or when a partial chunk has waited `--flush-ms` (200 ms), so a
  slow live source is not held back.
- **Timing:** each record's `t_us` is when its first byte arrived.
- **Alignment:** `--type video/mp2t` sets `--align 188`, so a record never
  splits a transport packet and a lost record costs whole packets.
- **Stopping:** SIGINT or SIGTERM ends the capture cleanly with an end record
  marked `interrupted`. SIGKILL leaves a verifiable prefix.

### G. The interface: record and play

| Command | Does |
|---|---|
| `record OUT [--input FILE] [--type MIME] [--key KEY] [--deflate] [--source URL] [--license TEXT] [--note TEXT]` | freeze stdin (a stream) or a file into `OUT` |
| `play IN -o FILE` | expand into the filesystem as a new file |
| `play IN` | the payload on stdout, as fast as it goes |
| `play IN --paced [--speed N]` | at the pace of capture, or N times it |
| `play IN --start S` | from S seconds into the capture |
| `play IN --follow` | read a file that is still being recorded, and stop at its end record |
| `play IN --serve [HOST]:PORT [--paced] [--follow] [--once]` | an HTTP server; each client, such as `vlc http://HOST:PORT/`, gets its own reader from the start, which makes a capture still being written a timeshift buffer |
| `verify IN [--allowed-signers FILE]` | repair in memory and report: records, repairs, losses, checkpoints, signatures, end |

`play` and `verify` exit 1 in any of these cases:
- a data record is lost;
- an entry or digest does not match;
- a signature is bad;
- the end record is missing or disagrees with the payload;
- a key is not in the given `allowed_signers`.

### H. The tty layer

`armor` turns any byte stream into lines:

```
-----BEGIN SSTR ARMOR v0-----
S<offset: 9 hex>:<45 bytes as 60 base64url characters>:<CRC-32 of what precedes the colon, 8 hex>
…
-----END SSTR ARMOR <length hex> <first 40 hex of the payload SHA-256>-----
```

The line format gives these guarantees:
- **Width:** a line is 80 columns and printable ASCII.
- **Flow control:** no line contains XON or XOFF, so software flow control
  still works.
- **Placement:** every line states its own offset, so a lost line is a known
  gap, not a shift.
- **Noise:** a line that fails its CRC, or is not armor at all (a kernel
  message on the same console), is dropped.

`recv` joins the lines back into the `.sstr` and gives the reader each lost
byte range as an erasure mask. `unarmor --erasures FILE` does the same
offline for `play` and `verify`.

On an 8N1 line the armor carries 45 bytes in 81, so a full-record `.sstr`
payload moves at about 11,520 × 45/81 / 1.224 ≈ 5,230 bytes/s at 115200 baud
and 436 bytes/s at 9600. `--baud` paces the sender so a receiver without
flow control is not overrun.

## IV. Method

### Materials

| Item | Value |
|---|---|
| Guest | Copal aarch64 under UTM, Alpine 3.24.1, kernel 6.18.50-0-virt, 4 CPUs |
| Prototype | `tools/copal-sstr.py`, Python 3.14.7 standard library only |
| Signing | OpenSSH 10.3p1 `ssh-keygen -Y`; throwaway Ed25519 keys `tester@sstr` and `stranger@sstr` |
| Streams | ffmpeg 8.1.2 `lavfi` test sources: 640×360 25 fps MPEG-2 video at 1500 kbit/s with MP2 audio at 128 kbit/s, and a 440 Hz MP2 tone at 64 kbit/s, both in MPEG-TS |
| Clients | mpv 0.41.0, VLC 3.0.23 (`cvlc`), curl 8.22.0 |
| Serial line | socat 1.8.1.3 pty pair, both ends `stty 115200` |
| Files | `copal-prep.sh` (1,687,746 bytes, text); a tar of `docs/` (10,199,040 bytes, mostly images); random data from `/dev/urandom` |

### Procedures

1. **The code.** `rs_correct()` was given 2,000 codewords (223, 100, 32 or 1
   data bytes) with random erasures f and errors e where 2e + f ≤ 32, and
   1,000 with 17 to 25 errors. Its integer-register encoder was compared with
   polynomial division, and a 4,000-byte burst was put into one 64 KiB body.
2. **Round trip.** 20 MB of random data was recorded, played with `-o` and
   compared with `cmp`, with timings.
3. **Live capture.**
   - `ffmpeg -re … -t 20 -f mpegts - | tee ref.ts | copal-sstr.py record
     cap.sstr --type video/mp2t --key key`.
   - Four seconds in, `play --follow -o follow.ts` started on the growing file.
   - After both finished: `ref.ts`, `follow.ts` and `play -o out.ts` were
     compared, and ffprobe counted packets. The records were listed by type,
     size and time, and `verify` ran.
   - `play --paced`, `--paced --speed 4` and `--start 10` were timed and probed.
4. **Clients.** `play --serve --once` was fetched with curl and compared, then
   played paced by `mpv --vo=null --ao=null --length=6` and by `cvlc`
   `--run-time=6` with `--verbose=2`.
5. **Damage.**
   - A 4 MB random payload was recorded signed, with a checkpoint every 32
     records, and a 500 KB payload in 16 KiB records.
   - A script corrupted copies in one of seven ways: random bit flips at a
     given rate, zeroed bursts, whole records overwritten with random bytes,
     both copies of the stream header record overwritten, truncation, and a
     data record re-encoded with one payload byte changed and its CRCs and
     Reed–Solomon parity recomputed.
   - Each copy was played with `-o`, compared, and verified against the
     signer's and a stranger's `allowed_signers`.
6. **Serial line.**
   - An 8-second 64 kbit/s tone was recorded as `audio/mp2t` in 4,136-byte
     records (22 transport packets), then armored. The armor's widths and
     bytes were checked.
   - It was sent with `armor --baud 115200` into one end of the pty pair,
     with `recv` on the other.
   - The armor was then piped through a noise script and into `recv`:
     - **drops** a chosen fraction of lines;
     - **flips** bits at a chosen rate, in every byte but the newline;
     - **injects** a kernel USB message every 50 lines.
   - These tests ran again after each of the two fixes in Section V-I.
7. **Files.** `copal-prep.sh` and the `docs/` tar were recorded with and
   without `--deflate`, expanded with `play -o` and compared. Their sizes were
   set against `gzip -6`, `xz -6` and `zstd -3`.

## V. Results

### A. The code

| Test | Result |
|---|---|
| 2,000 codewords within 2e + f ≤ 32 | 2,000 corrected, 0 failed |
| 1,000 codewords with 17–25 errors | 1,000 reported uncorrectable, 0 decoded to a wrong codeword |
| integer-register encoder against polynomial division | identical |
| 4,000-byte burst in a 64 KiB interleaved body | rebuilt; 4,000 bytes corrected in 0.50 s |

### B. Round trip and overhead

| Input | `.sstr` bytes | Ratio | Time |
|---|---|---|---|
| 20 MB random, 64 KiB records | 24,485,254 | 1.2242 | record 2.98 s (6.7 MB/s); `play -o` 0.16 s, identical |
| 4 MB random, signed, checkpoint every 32 | 4,902,582 | 1.2256 | |
| 500 KB random, 16 KiB records, signed | 625,299 | 1.2506 | |
| 20 s live MPEG-TS, 1,871,352 bytes | 2,440,702 | 1.3042 | recorded in real time |
| 8 s 64 kbit/s TS, 78,020 bytes, 4,136-byte records | 110,421 | 1.4153 | |

On the live capture the bytes on disk break down as:

| Records | On disk | Share of the payload |
|---|---|---|
| 88 data | 2,153,240 | 115.1 % |
| 6 parity | 264,852 | 14.2 % |
| 4 checkpoint copies | 20,444 | 1.1 % |
| 2 header and 2 end copies | 2,158 | 0.1 % |

The data records ran from 9,776 to 65,424 bytes, 21,265 on average, every
one but the last a whole number of 188-byte packets. Their times ran from
0.00 to 19.40 s.

### C. A live stream, captured and played while captured

| Check | Result |
|---|---|
| recorder finished | 19.59 s after ffmpeg started |
| `play --follow` (started at 4 s) finished | 19.69 s, exit 0 |
| `follow.ts`, `out.ts` against `ref.ts` | both identical |
| ffprobe packets, reference and replay | MPEG-2 video 500, MP2 834; the same |
| `verify` | payload SHA-256 matches the end record; 2 checkpoints good, 90 entries verified; 2 signatures good, through record 96 of 97 |
| `play --paced` | 19.48 s |
| `play --paced --speed 4` | 4.95 s |
| `play --start 10` | 894,692 bytes; `start_time` 11.846 s against the reference's 1.430 s, so 10.42 s into the stream; 9.60 s long |

### D. Serving players

| Client | Result |
|---|---|
| curl, `play --serve --once` | `HTTP/1.0 200 OK`, `Content-Type: video/mp2t`; 1,871,352 bytes in 0.1 s, identical |
| mpv, served `--paced` | `mpv playing: video MPEG-2 video 640x360 @ 25 fps, audio mp2 48000 Hz`; returned after 6.52 s for `--length=6` |
| VLC (`cvlc`), served `--paced` | `using demux module "ts"`, decoders `mpgv` and `mpga`; returned after 7.30 s for `--run-time=6` |

The server logged each player that left early as `left: [Errno 32] Broken
pipe`.

### E. Damage

The 4 MB signed capture unless marked; "500 KB" is the 16 KiB-record capture.

| Damage | Payload | Exit | What `verify` reported |
|---|---|---|---|
| none | identical | 0 | 2 checkpoints good, 64 entries verified, 2 signatures good; key "trusted as tester@sstr" |
| bit errors 1e-5 (392 bits) | identical | 0 | 391 body bytes corrected in 64 records; 1.05 s to play |
| bit errors 1e-4 (3,922 bits) | identical | 0 | 3,916 body bytes corrected in 70 records; 4.54 s |
| bit errors 1e-3, 500 KB (5,002 bits) | identical | 0 | 11 header and 4,946 body bytes corrected; 2.56 s |
| bit errors 3e-3, 500 KB (15,007 bits) | identical | 0 | 52 header and 14,714 body bytes corrected; 3.21 s |
| bit errors 1e-2, 500 KB (50,023 bits) | nothing | 1 | 31 data records lost; no header or checkpoint survived, so no key |
| 4 KiB zeroed at byte 1,500,000, over a record's headers | identical | 0 | 75,080 bytes skipped in a resync; 1 record rebuilt from parity |
| 4 KiB zeroed at byte 1,540,000, inside a body | identical | 0 | 4,081 body bytes corrected in 1 record; 0.53 s |
| 60 KiB zeroed | identical | 0 | 1 record rebuilt from parity |
| 200 KiB zeroed | 3,803,392 bytes | 1 | 3 data records lost in one group; 3 entries unaccounted; signatures still good |
| one data record randomised | identical | 0 | 1 rebuilt from parity |
| two, in different groups | identical | 0 | 2 rebuilt from parity |
| two, in the same group | 3,868,928 bytes | 1 | 2 data records lost |
| both copies of the stream header record randomised | identical | 0 | key taken from a checkpoint; 1 entry (the header) unaccounted; 2 signatures good |
| truncated at 60 % | 2,424,832 bytes | 1 | 1 checkpoint good; signed through record 32 of 40; "end missing: the capture stopped without closing" |
| record 11 re-encoded with byte 1000 changed | 4,000,000 bytes | 1 | 1 checkpoint bad, 1 entry mismatched; both signatures good |
| none, checked against the stranger's `allowed_signers` | identical | 1 | "NOT in allowed2" |

### F. The tty layer on a pty

The 110,421-byte capture armored into 2,456 lines and 198,864 bytes. The
longest line was 80 columns, and no line held a byte outside printable ASCII
or an XON or XOFF. The first line and the last:

```
S000000000:iVNTVA0KGgqnU1NSSAAAAAAAAAAAAAAAUwAAAAAAAADVAQAAuuWhqNzNTFu3:a579734a
-----END SSTR ARMOR 1af55 f4e866e156c2308b151fb0d73b062b3a83a4ba25-----
```

The first line decodes to the file signature, `\x89SST\r\n\x1a\n`, and the
start of the first header, `\xa7SSR` `H`. Sent with `--baud 115200` through
the socat pair:
- **Speed:** 198,864 bytes took 17.33 s, which is 11,471 bytes/s against a
  theoretical 11,520, and 4,500 payload bytes/s.
- **Loss:** `recv` read 2,454 lines, none failing its CRC and nothing lost.
- **Result:** exit 0, the payload identical, one signature good.

### G. The tty layer on a noisy line

"Line bytes lost" is what `recv` had to mark as erasures, against the
110,421-byte `.sstr`. Where a console line was injected every 50 lines,
49 of the "not armor" lines are those injections.

| Lines dropped | Bit errors | Console | Exit | Payload | Line bytes lost | Records lost |
|---|---|---|---|---|---|---|
| 1 % | — | yes | 0 | identical | 1,035 (0.9 %) | none; 919 body bytes corrected |
| 5 % | — | yes | 0 | identical | 5,940 (5.4 %) | none; 5,567 body bytes corrected |
| 8 % | — | — | 1 | 69,748 of 78,020 | 9,225 (8.4 %) | 2 data |
| 10 % | — | yes | 1 | 65,612 | 11,430 (10.4 %) | 3 data, 2 unknown, 1 parity |
| 12 % | — | — | 1 | 33,088 | 13,680 (12.4 %) | 11 data, 2 unknown, 1 parity |
| 15 % | — | — | 1 | 20,680 | 16,335 (14.8 %) | 14 data, 3 unknown, 2 parity |
| — | 1e-4 | yes | 0 | identical | 7,560 (6.8 %): 82 CRC failures, 86 corrupted beyond recognition | 1 unknown (the stream header); key from a checkpoint |
| — | 2e-4 | — | 1 | 44,932 | 13,005 (11.8 %) | 8 data, 2 unknown; no key recovered |
| — | 5e-4 | — | 1 | nothing | 29,961 (27.1 %) | 16 data, 7 unknown |
| 5 % | 1e-4 | yes | 1 | 33,088 | 13,230 (12.0 %) | 11 data, 1 unknown |

### H. Files

| File | Original | `record --deflate` | `record` | gzip -6 | xz -6 | zstd -3 |
|---|---|---|---|---|---|---|
| `copal-prep.sh` | 1,687,746 | 746,849 (0.443), 0.19 s | 2,092,556 (1.240) | 565,669 (0.335) | 450,100 (0.267) | 556,474 (0.330) |
| `docs/` tar | 10,199,040 | 11,310,555 (1.109), 1.61 s | 12,473,000 (1.223) | 9,067,875 (0.889) | 8,530,080 (0.836) | 8,904,561 (0.873) |

Both expanded with `play -o` identical to the original.

### I. What failed first

**Parity that could not rebuild.** One data record randomised in the first
version gave "1 data records lost, 0 records rebuilt from parity". The reader
played each record as soon as it could and discarded its body. So when the
parity record arrived, the group's good records looked missing too, and more
than one missing record is beyond XOR. The reader now keeps good bodies until
their group's parity has been used; the same test rebuilds the record (V-E).

**One header copy.** In the first version each record header was written
once. On the noisy line with 5 % of lines dropped, the payload came through,
but 1 record of unknown type was lost and 5,278 bytes were skipped in a
resync. A dropped line is 45 bytes, more than the 32 erasures a 64-byte
header codeword can take. With two copies the same test lost nothing. The
runs are not strictly comparable: the new layout moves every byte, so each
dropped line lands elsewhere.

**A lost stream header counted as a bad signature.** With bit errors at 1e-4
on the line, the first version delivered the payload identical but exited 1
with "0 good, 1 bad" signatures. Both copies of the small stream header
record had been lost: they are adjacent, and a 1.4 KB record has little
interleaving. With no key known, the reader called the signature bad. Every
checkpoint now carries the header, and a signature that cannot yet be
checked is counted apart from a bad one. The same test now exits 0 with one
good signature (V-G). The first version's END line was 95 columns wide; it
now gives 40 hex digits of the hash.

## VI. Discussion

**What "static" buys.** A static stream plays three ways:
- **Tape:** in order at its own pace. `--paced` took 19.48 s for records
  stamped over 19.40 s.
- **Archive:** expanded as fast as the disk allows, 0.16 s for 20 MB.
- **Broadcast:** joined while still arriving, which `--follow` did from
  4 seconds in, finishing 0.1 s after the recorder.

The server makes a growing capture into VideoLAN's split. `play` is the
server, every player is a client, and each client reads from the start, so a
viewer who arrives late is time-shifted rather than turned away. Carrying
the stream header in every checkpoint is what makes joining mid-stream
possible without the first record.

**The 20 percent, and what it buys.** The budget went on two codes of
different kinds:
- **Inner:** RS(255,223) with interleaving corrected every scattered bit
  error up to a rate of 3e-3, and a 4,000-byte burst inside one record.
- **Outer:** one XOR parity per 16 records rebuilt any single record lost
  outright, including one whose headers a burst destroyed.

The measured cliff is where the design says it is:
- **Bit errors:** at 1e-2, 8 % of bytes are wrong, about 20 per codeword
  against a limit of 16, and everything is lost.
- **Bursts:** a 200 KiB burst destroyed three records of one group, beyond
  what XOR can do.

A different split of the same budget would suit a different channel.
DVB-S [14] spends about 8.5 % on RS(204,188) per packet and relies on an
interleaver and a convolutional code. SMPTE 2022-1's L = D = 10 matrix [26]
spends exactly 20 % on XOR parity alone, for a channel that loses whole
packets.

**The outer code is the weak part, and the fix is known.** XOR parity was
chosen because it is a dozen lines. Its limits showed in two places:
- **Capacity:** it rebuilds one record per group.
- **Cost:** a parity body is as long as its group's longest record, so on a
  live capture whose records averaged a third of their maximum it cost
  14.2 % of the payload, not the nominal 6.25 %.

Replacing it with a Reed–Solomon erasure code over fixed-size stripes, as
PAR2 does over files [25], or with RaptorQ [27], would rebuild several
records per group at the same cost and make parity independent of record
sizes.

**Interleaving depth and the serial cliff.** On the tty test, a record body
of 4,136 bytes is 19 codewords, so a dropped 45-byte line puts two or three
erasures into each. The code takes 32 erasures per codeword, 12.5 % of its
bytes. But lost lines cluster by chance, and small records have little room
to spread them, so the measured limit was lower:
- **Survived:** 5.4 % of line bytes lost to dropped lines, and 6.8 % to bit
  errors.
- **Failed:** from 8.4 %.

Two changes would push that up:
- **Interleave across records**, as DVB's convolutional interleaver spreads
  bytes across twelve packets [14], so a run of lost lines never falls on
  one record.
- **Use larger records on serial links**, at the price of latency.

A receiver with a return channel could also ask for missing offsets again,
as XMODEM and ZMODEM did [41]. The armor already names every line's offset,
so that needs no format change.

**Is a block cipher with an IV and a seed a stream?** A block cipher alone is
not: it maps one block to one block. Its modes make it one [29]:
- **CTR** turns AES and a nonce into a keystream generator. That is a stream
  cipher, and appending is continuing the counter.
- **CBC** chains each block to the previous ciphertext. Appending works too,
  because the last ciphertext block is the IV for the next.

Neither gives integrity, and neither is needed here, since nothing is secret.
What `.sstr` keeps from the idea is the shape, not the cipher:
- **A random per-stream value:** the stream id plays the IV's part, so two
  captures of the same bytes give different chains.
- **Chaining:** each checkpoint digest folds in the one before it.
- **An end marker:** the end record, like age's final-chunk flag [30],
  distinguishes a finished capture from a truncated one.

"Seed" fits a second way too. A checkpoint's `[seq, SHA-256]` entries are
the per-piece hashes a BitTorrent-style swarm [35] would need to fetch and
check a capture piece by piece from several seeders. That is not
implemented.

**Signed, not encrypted, with keys people already have.** An SSH key is
already on every developer's machine, and `ssh-keygen -Y` [36] needs no new
dependency and no new key format. A signature proves only that the key's
holder recorded these bytes and that none has changed since; who that holder
is, is a separate question. So `verify` reports validity and trust apart:
- **Validity:** a signature checked against the key in the file.
- **Trust:** given an `allowed_signers`, whether that key is one expected.
  An untrusted key fails the run.

`play` writes records as they come and verifies at checkpoints. In the
tampering test it wrote the changed payload and only then exited 1. For an
archive, `verify` first, or `play -o` and check the exit status before using
the file.

**No codecs, by design.** The format never decodes, so it needs no codec
and no third-party library, and whatever plays MPEG-TS plays the output,
byte for byte. The cost is that `--start` cuts at a record boundary, not a
keyframe. The replay began 10.42 s in, mid-GOP, and a decoder shows nothing
until the next I-frame. A future version could index keyframes the capture
already contains, the random-access indicator of an MPEG-TS adaptation field
[13], without decoding anything.

**Compression is for files, not streams.** `--deflate` compresses each record
on its own with the standard library's zlib, and keeps a record raw unless
that saves 5 %. On text it came to 0.443 of the original, against gzip's
0.335. Most of the gap is the 22 % redundancy (0.335 × 1.22 ≈ 0.41); the
rest is the dictionary restarting at every record. On a tar of mostly
compressed images it made the capture 9 % smaller than recording without it,
but still 11 % larger than the original. zstd [20] would do better and is the obvious next
choice, but it is a dependency the prototype set out not to have. A captured
video stream is already compressed, so `--deflate` there would mostly spend
time. That was not measured.

**Speed.** The prototype is pure Python:
- **Recording:** 6.7 MB/s, almost all of it Reed–Solomon encoding, done as
  three integer operations per byte rather than 32 table lookups.
- **Clean playback:** checks one CRC per record, 125 MB/s.
- **Repair:** runs the full decoder, about 1 MB/s at a bit error rate of
  1e-4.

A C implementation of the same format would be one to two orders of
magnitude faster. Nothing in the format depends on the language.

**What a static stream does not settle.** A new container changes the form
of a copy, not whether the copy may be made. *Sony* [8] held home
time-shifting of free broadcast television fair; it did not bless every
recording of every stream. A stream received under a site's terms is not a
broadcast, and the review of `ytq`'s wording in
`docs/ytq-clipboard-lab-report.md` applies here unchanged:
- **Fidelity:** a faithful copy is still a copy.
- **Credit:** crediting a source does not license copying it.

A signature adds provenance (who recorded, when, and that nothing changed)
and nothing more. The stream header's `--source` and `--license` fields are
there so a capture can say where it came from and under what terms, as
`ytq`'s notes do for a video.

**Where it sits among its neighbours.** The novelty is the combination, not
any piece:

| Neighbour | Has | Lacks |
|---|---|---|
| MPEG-TS over DVB-S [13], [14] | per-packet Reed–Solomon and interleaving | a file, signatures, pace |
| PAR2 [25] | strong erasure coding | does not stream |
| journald sealing [33], Certificate Transparency [34] | sealed, chained logs | error correction |
| age [30] | chunks a stream and marks its end | is encrypted |
| asciicast [17], pcapng [16] | keep time | no protection |

`.sstr` is those pieces, chosen for a stream that must survive storage and a
bad serial line, and come back out as the stream it was.

## VII. Procedures

**Freeze a live stream, signed, and watch it while it records:**

```sh
ffmpeg -i "$SOURCE" -c copy -f mpegts - | tools/copal-sstr.py record cap.sstr \
    --type video/mp2t --key ~/.ssh/id_ed25519 --source "$SOURCE" --license "as stated by the source"
tools/copal-sstr.py play cap.sstr --follow | mpv -
```

**Let it go again:**

```sh
tools/copal-sstr.py play cap.sstr -o cap.ts                  # a new file
tools/copal-sstr.py play cap.sstr --paced | mpv -            # at the pace it came
tools/copal-sstr.py play cap.sstr --serve :8080 --paced      # then: vlc http://GUEST:8080/
```

**Check a capture, and whose it is:**

```sh
echo "me@host namespaces=\"sstr@copal\" $(cat ~/.ssh/id_ed25519.pub)" > ~/.config/sstr-allowed
tools/copal-sstr.py verify cap.sstr --allowed-signers ~/.config/sstr-allowed
```

**Record a file compressed, and expand it:**

```sh
tools/copal-sstr.py record big.tar.sstr --input big.tar --deflate
tools/copal-sstr.py play big.tar.sstr -o big.tar
```

**Send a capture over a serial line** (`stty` on both ends first, and pace
to the slower):

```sh
stty -F /dev/ttyS0 115200 raw -echo
tools/copal-sstr.py armor cap.sstr --baud 115200 > /dev/ttyS0        # sender
tools/copal-sstr.py recv /dev/ttyS0 -v > cap.ts                       # receiver
```

**The same over a console already in use, offline:**

```sh
tools/copal-sstr.py unarmor console.log --erasures lost.json > cap.sstr
tools/copal-sstr.py verify cap.sstr --erasures lost.json
```

## VIII. Files touched

| File | Change |
|---|---|
| `tools/copal-sstr.py` | new: the version-0 format; `record`, `play` (stdout, `-o`, `--paced`, `--speed`, `--start`, `--follow`, `--serve`), `verify`, `armor`, `unarmor`, `recv`. Commit `6fa0b0d` |
| `docs/static-stream-lab-report.md` | this report |

## References

[1] L. V. Hau, S. E. Harris, Z. Dutton, and C. H. Behroozi, "Light speed reduction to 17 metres per second in an ultracold atomic gas," *Nature*, vol. 397, pp. 594–598, 1999, doi: 10.1038/17561.

[2] C. Liu, Z. Dutton, C. H. Behroozi, and L. V. Hau, "Observation of coherent optical information storage in an atomic medium using halted light pulses," *Nature*, vol. 409, pp. 490–493, 2001, doi: 10.1038/35054017.

[3] D. F. Phillips, A. Fleischhauer, A. Mair, R. L. Walsworth, and M. D. Lukin, "Storage of light in atomic vapor," *Phys. Rev. Lett.*, vol. 86, p. 783, 2001, doi: 10.1103/PhysRevLett.86.783.

[4] M. Fleischhauer and M. D. Lukin, "Dark-state polaritons in electromagnetically induced transparency," *Phys. Rev. Lett.*, vol. 84, p. 5094, 2000, doi: 10.1103/PhysRevLett.84.5094.

[5] G. Heinze, C. Hubrich, and T. Halfmann, "Stopped light and image storage by electromagnetically induced transparency up to the regime of one minute," *Phys. Rev. Lett.*, vol. 111, p. 033601, 2013, doi: 10.1103/PhysRevLett.111.033601.

[6] Y. Ma, Y.-Z. Ma, Z.-Q. Zhou, C.-F. Li, and G.-C. Guo, "One-hour coherent optical storage in an atomic frequency comb memory," *Nat. Commun.*, vol. 12, p. 2381, 2021, doi: 10.1038/s41467-021-22706-y.

[7] "Flashback 1975: The VCR is born," *Sound & Vision*. [Online]. Available: https://www.soundandvision.com/content/flashback-1975-vcr-born

[8] *Sony Corp. of America v. Universal City Studios, Inc.*, 464 U.S. 417 (1984). [Online]. Available: https://tile.loc.gov/storage-services/service/ll/usrep/usrep464/usrep464417/usrep464417.pdf

[9] VideoLAN, "VideoLAN – the project." [Online]. Available: https://www.videolan.org/videolan/

[10] VideoLAN, VLC source: `src/libvlc-module.c`, `modules/demux/demuxdump.c`, `modules/stream_out/standard.c`; "Demuxdump," VideoLAN Wiki. [Online]. Available: https://github.com/videolan/vlc, https://wiki.videolan.org/Demuxdump/

[11] mpv manual, `--stream-record`, https://mpv.io/manual/stable/; FFmpeg documentation, stream copy and the `mpegts` muxer, https://ffmpeg.org/ffmpeg.html, https://ffmpeg.org/ffmpeg-formats.html#mpegts-1

[12] "ReplayTV and TiVo personal video recorders hit the market in 1999," CED Magic. [Online]. Available: https://www.cedmagic.com/history/replay-tivo.html

[13] *Generic Coding of Moving Pictures and Associated Audio Information: Systems*, ITU-T Rec. H.222.0 | ISO/IEC 13818-1. [Online]. Available: https://www.itu.int/rec/T-REC-H.222.0

[14] *Digital Video Broadcasting (DVB); Framing structure, channel coding and modulation for 11/12 GHz satellite services*, ETSI EN 300 421 V1.1.2, 1997. [Online]. Available: https://www.etsi.org/deliver/etsi_en/300400_300499/300421/01.01.02_60/en_300421v010102p.pdf

[15] S. Pfeiffer, "The Ogg encapsulation format version 0," RFC 3533, 2003.

[16] "PCAP Now Generic (pcapng) capture file format," IETF Internet-Draft draft-ietf-opsawg-pcapng-05, Mar. 2026, work in progress. [Online]. Available: https://datatracker.ietf.org/doc/draft-ietf-opsawg-pcapng/

[17] asciinema, "asciicast v2" and "asciicast v3" file formats. [Online]. Available: https://docs.asciinema.org/manual/asciicast/v2/

[18] *Information and documentation — WARC file format*, ISO 28500:2017.

[19] *IEEE Standard for Information Technology—Portable Operating System Interface (POSIX)*, IEEE Std 1003.1, `pax`: ustar interchange format.

[20] Y. Collet and M. Kucherawy, "Zstandard compression and the 'application/zstd' media type," RFC 8878, 2021; "Zstandard seekable format," https://github.com/facebook/zstd/tree/dev/contrib/seekable_format

[21] L. Collin and I. Pavlov, "The .xz file format," v1.2.1. [Online]. Available: https://tukaani.org/xz/xz-file-format.txt

[22] I. S. Reed and G. Solomon, "Polynomial codes over certain finite fields," *J. SIAM*, vol. 8, no. 2, pp. 300–304, 1960.

[23] *TM Synchronization and Channel Coding*, CCSDS 131.0-B-5, Blue Book, Sep. 2023. [Online]. Available: https://ccsds.org/Pubs/131x0b5.pdf

[24] DENSO WAVE, "Error correction feature," QR code; *QR Code bar code symbology specification*, ISO/IEC 18004:2015. [Online]. Available: https://www.qrcode.com/en/about/error_correction.html

[25] Parchive, par2cmdline. [Online]. Available: https://github.com/Parchive/par2cmdline

[26] *Forward Error Correction for Real-Time Video/Audio Transport over IP Networks*, SMPTE ST 2022-1:2007.

[27] "RaptorQ forward error correction scheme for object delivery," RFC 6330, Aug. 2011. [Online]. Available: https://www.rfc-editor.org/info/rfc6330

[28] M. Luby, "LT codes," in *Proc. 43rd IEEE Symp. Foundations of Computer Science*, 2002, pp. 271–280.

[29] M. Dworkin, *Recommendation for Block Cipher Modes of Operation: Methods and Techniques*, NIST SP 800-38A, 2001.

[30] C2SP, "age-encryption.org/v1." [Online]. Available: https://github.com/C2SP/C2SP/blob/main/age.md

[31] V. T. Hoang, R. Reyhanitabar, P. Rogaway, and D. Vizár, "Online authenticated-encryption and its nonce-reuse misuse-resistance," in *Advances in Cryptology — CRYPTO 2015*, LNCS 9215, pp. 493–517.

[32] libsodium, "Encrypted streams and file encryption." [Online]. Available: https://doc.libsodium.org/secret-key_cryptography/secretstream

[33] journalctl(1), `--setup-keys`, `--interval`, `--verify`. [Online]. Available: https://man7.org/linux/man-pages/man1/journalctl.1.html

[34] B. Laurie, A. Langley, and E. Kasper, "Certificate Transparency," RFC 6962, 2013; B. Laurie, E. Messeri, and R. Stradling, "Certificate Transparency version 2.0," RFC 9162, 2021.

[35] BitTorrent, "The BitTorrent Protocol Specification v2," BEP 52. [Online]. Available: https://www.bittorrent.org/beps/bep_0052.html

[36] OpenSSH 8.1 release notes, 2019. [Online]. Available: https://www.openssh.org/txt/release-8.1

[37] J. Satran et al., "Internet Small Computer Systems Interface (iSCSI)," RFC 3720, 2004, §12.1; "ext4 metadata checksums," https://docs.kernel.org/filesystems/ext4/checksums.html

[38] S. Josefsson, "The Base16, Base32, and Base64 data encodings," RFC 4648, 2006; Adobe, *PostScript Language Reference*, 3rd ed., ASCII85Decode.

[39] N. Freed and N. Borenstein, "MIME Part One: Format of Internet message bodies," RFC 2045, 1996, §6.8.

[40] M. A. Horton, interview, *;login:*, USENIX, Spring 2020. [Online]. Available: https://www.usenix.org/system/files/login/articles/spring20_09_horton.pdf

[41] C. Forsberg, "XMODEM/YMODEM protocol reference," 1988. [Online]. Available: http://pauillac.inria.fr/~doligez/zmodem/ymodem.txt

[42] The Kermit Project, Columbia University. [Online]. Available: https://www.kermitproject.org/kermit.html

[43] Intel, *Hexadecimal Object File Format Specification*, Rev. A, 1988.

[44] J. Romkey, "A nonstandard for transmission of IP datagrams over serial lines: SLIP," RFC 1055, 1988.

[45] S. Cheshire and M. Baker, "Consistent overhead byte stuffing," *IEEE/ACM Trans. Netw.*, vol. 7, no. 2, pp. 159–172, 1999, doi: 10.1109/90.769765.

[46] *Information technology — ISO 7-bit coded character set for information interchange*, ISO/IEC 646 (DC1 0x11, DC3 0x13).

[47] *Portable Network Graphics (PNG) Specification*, §5.2 and "Rationale" §12.12; W3C PNG Third Edition, 2025. [Online]. Available: http://www.libpng.org/pub/png/spec/1.2/PNG-Rationale.html

[48] *Space data and information transfer systems — Open archival information system (OAIS) — Reference model*, ISO 14721:2025.

[49] J. Kunze, J. Littman, E. Madden, J. Scancella, and C. Adams, "The BagIt file packaging format (V1.0)," RFC 8493, 2018.
