#!/usr/bin/env python3
"""
Speaker Diarization Script using pyannote.audio
Identifies speakers in an audio file and outputs timestamps with speaker labels

NOTE: Currently disabled due to pyannote.audio compatibility with PyTorch 2.9+
This script is ready and will work once pyannote.audio releases a compatible update.
Track: https://github.com/pyannote/pyannote-audio/issues
"""

import sys
import json
from pathlib import Path

try:
    from pyannote.audio import Pipeline
    import torch
except ImportError:
    print("ERROR: pyannote.audio not installed. Run: pip install pyannote.audio torch", file=sys.stderr)
    sys.exit(1)


def diarize_audio(audio_file, output_file=None, min_speakers=None, max_speakers=None):
    """
    Perform speaker diarization on an audio file
    
    Args:
        audio_file: Path to audio file
        output_file: Path to save diarization results (JSON)
        min_speakers: Minimum number of speakers (optional)
        max_speakers: Maximum number of speakers (optional)
    
    Returns:
        Dictionary with speaker segments
    """
    try:
        # Initialize the pipeline
        # Note: First run will download the model (~300MB)
        pipeline = Pipeline.from_pretrained(
            "pyannote/speaker-diarization-3.1",
            use_auth_token=None  # Public model, no token needed
        )
        
        # Use GPU if available
        if torch.cuda.is_available():
            pipeline.to(torch.device("cuda"))
        
        # Run diarization
        print(f"Processing: {audio_file}", file=sys.stderr)
        diarization_params = {}
        if min_speakers:
            diarization_params['min_speakers'] = min_speakers
        if max_speakers:
            diarization_params['max_speakers'] = max_speakers
            
        diarization = pipeline(audio_file, **diarization_params)
        
        # Convert to structured format
        segments = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segments.append({
                'start': float(turn.start),
                'end': float(turn.end),
                'speaker': speaker
            })
        
        result = {
            'audio_file': str(audio_file),
            'num_speakers': len(set(seg['speaker'] for seg in segments)),
            'segments': segments
        }
        
        # Save to file if specified
        if output_file:
            with open(output_file, 'w') as f:
                json.dump(result, f, indent=2)
            print(f"Saved diarization to: {output_file}", file=sys.stderr)
        
        return result
        
    except Exception as e:
        print(f"ERROR: Diarization failed: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("Usage: diarize_speakers.py <audio_file> [output_json] [min_speakers] [max_speakers]", file=sys.stderr)
        print("Example: diarize_speakers.py recording.mp3 diarization.json 2 4", file=sys.stderr)
        sys.exit(1)
    
    audio_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    min_speakers = int(sys.argv[3]) if len(sys.argv) > 3 else None
    max_speakers = int(sys.argv[4]) if len(sys.argv) > 4 else None
    
    if not Path(audio_file).exists():
        print(f"ERROR: Audio file not found: {audio_file}", file=sys.stderr)
        sys.exit(1)
    
    result = diarize_audio(audio_file, output_file, min_speakers, max_speakers)
    
    # Print summary
    print(f"\nDiarization complete!", file=sys.stderr)
    print(f"Detected {result['num_speakers']} speakers", file=sys.stderr)
    print(f"Total segments: {len(result['segments'])}", file=sys.stderr)
    
    # Output JSON to stdout for piping
    print(json.dumps(result))


if __name__ == "__main__":
    main()

