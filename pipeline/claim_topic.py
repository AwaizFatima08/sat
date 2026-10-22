#!/usr/bin/env python3
"""Claim a passage topic before writing it, so parallel writers never collide.

  python3 pipeline/claim_topic.py BATCH "short topic phrase"   -> prints CLAIMED or TAKEN (with the clash)

A topic is TAKEN if an earlier claim shares 2+ significant words with it. Claims live in
content/rw/topic_claims.tsv (committed, so later writers see them too).
"""
import fcntl
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLAIMS = ROOT / "content" / "rw" / "topic_claims.tsv"
STOP = set("the and with from that this into their about over under after before among between ancient early "
           "modern study studies effect effects role history new how why what".split())


def words(s):
    return {w for w in re.findall(r"[a-z]+", s.lower()) if len(w) > 3 and w not in STOP}


def main():
    batch, topic = sys.argv[1], " ".join(sys.argv[2:])
    mine = words(topic)
    CLAIMS.touch()
    with open(CLAIMS, "r+") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        for line in f.read().splitlines():
            b, _, t = line.partition("\t")
            if len(mine & words(t)) >= 2 or (len(mine) == 1 and mine <= words(t)):
                print(f"TAKEN by {b}: {t}")
                return
        f.write(f"{batch}\t{topic}\n")
        print("CLAIMED")


if __name__ == "__main__":
    main()
