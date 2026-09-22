#!/bin/bash
# Local scheduled backup for ForHumanity research data
set -e
SRC="/home/mort/ai/ideas"
DEST="/home/mort/ai/backups"
DATE=$(date -u +"%Y%m%d_%H%M%S")
BACKUP_DIR="$DEST/$DATE"
mkdir -p "$BACKUP_DIR"
echo "[$(date -Iseconds)] Backup $DATE to $BACKUP_DIR"
# Core research data
cp "$SRC/board.json" "$BACKUP_DIR/"
cp "$SRC/board.json" "$BACKUP_DIR/board_${DATE}.json"
cp "$SRC/report.html" "$BACKUP_DIR/" 2>/dev/null || true
cp "$SRC/report.pdf" "$BACKUP_DIR/" 2>/dev/null || true
cp $SRC/report_*.html "$BACKUP_DIR/" 2>/dev/null || true
cp $SRC/report_*.pdf "$BACKUP_DIR/" 2>/dev/null || true
cp $SRC/prompt_*.md "$BACKUP_DIR/" 2>/dev/null || true
cp "$SRC/schema.json" "$BACKUP_DIR/" 2>/dev/null || true
cp "$SRC/README.md" "$BACKUP_DIR/" 2>/dev/null || true
# Git bundle for full history
git -C "$SRC" bundle create "$BACKUP_DIR/repo.bundle" --all 2>&1 | head -5
# Tar
tar -czf "$DEST/backup_${DATE}.tar.gz" -C "$DEST" "$DATE" 2>&1 | head -5
# Keep only last 1000 backups (both dir and tar)
ls -dt "$DEST"/20* 2>/dev/null | tail -n +1001 | xargs -r rm -rf
ls -dt "$DEST"/backup_*.tar.gz 2>/dev/null | tail -n +1001 | xargs -r rm -f
ls -lh "$DEST" | tail -10
echo "[$(date -Iseconds)] Backup done $BACKUP_DIR, size $(du -sh $BACKUP_DIR | cut -f1), tasks $(cat $SRC/board.json | python3 -c 'import json; print(len(json.load(open("board.json"))["tasks"]))' 2>&1)"
