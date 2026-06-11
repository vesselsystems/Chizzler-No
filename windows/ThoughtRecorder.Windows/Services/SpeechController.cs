using System;
using System.Linq;
using System.Speech.Recognition;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace ThoughtRecorder.Windows.Services;

internal sealed class SpeechController : IDisposable
{
    private readonly object gate = new();
    private readonly StringBuilder transcript = new();

    private SpeechRecognitionEngine? engine;
    private TaskCompletionSource<string>? stopCompletion;
    private bool isRecording;

    public void StartRecording()
    {
        lock (gate)
        {
            if (isRecording)
            {
                return;
            }

            transcript.Clear();
            stopCompletion = new TaskCompletionSource<string>(TaskCreationOptions.RunContinuationsAsynchronously);
            engine = CreateEngine();
            isRecording = true;
        }

        try
        {
            engine.LoadGrammar(new DictationGrammar());
            engine.SpeechRecognized += HandleSpeechRecognized;
            engine.RecognizeCompleted += HandleRecognizeCompleted;
            engine.SetInputToDefaultAudioDevice();
            engine.RecognizeAsync(RecognizeMode.Multiple);
        }
        catch
        {
            CleanupEngine();
            lock (gate)
            {
                isRecording = false;
                stopCompletion = null;
            }
            throw;
        }
    }

    public async Task<string> StopRecordingAsync()
    {
        SpeechRecognitionEngine? activeEngine;
        TaskCompletionSource<string>? completion;

        lock (gate)
        {
            if (!isRecording)
            {
                return transcript.ToString();
            }

            isRecording = false;
            activeEngine = engine;
            completion = stopCompletion;
        }

        if (activeEngine is null || completion is null)
        {
            return transcript.ToString();
        }

        try
        {
            activeEngine.RecognizeAsyncStop();
        }
        catch
        {
            CompleteStop();
        }

        var completed = await Task.WhenAny(completion.Task, Task.Delay(TimeSpan.FromSeconds(1.5)));
        if (completed == completion.Task)
        {
            return await completion.Task;
        }

        CompleteStop();
        return transcript.ToString();
    }

    public void CancelRecording()
    {
        lock (gate)
        {
            isRecording = false;
            transcript.Clear();
        }

        try
        {
            engine?.RecognizeAsyncCancel();
        }
        catch
        {
            CompleteStop();
        }
    }

    private SpeechRecognitionEngine CreateEngine()
    {
        var recognizer = SpeechRecognitionEngine.InstalledRecognizers()
            .FirstOrDefault(info => string.Equals(info.Culture.Name, "en-US", StringComparison.OrdinalIgnoreCase))
            ?? SpeechRecognitionEngine.InstalledRecognizers().FirstOrDefault();

        if (recognizer is null)
        {
            throw new InvalidOperationException("No Windows speech recognizer is installed.");
        }

        return new SpeechRecognitionEngine(recognizer);
    }

    private void HandleSpeechRecognized(object? sender, SpeechRecognizedEventArgs e)
    {
        var text = e.Result?.Text;
        if (string.IsNullOrWhiteSpace(text))
        {
            return;
        }

        lock (gate)
        {
            if (transcript.Length > 0)
            {
                transcript.Append(' ');
            }

            transcript.Append(text);
        }
    }

    private void HandleRecognizeCompleted(object? sender, RecognizeCompletedEventArgs e)
    {
        CompleteStop();
    }

    private void CompleteStop()
    {
        TaskCompletionSource<string>? completion;
        string finalTranscript;

        lock (gate)
        {
            completion = stopCompletion;
            stopCompletion = null;
            finalTranscript = transcript.ToString();
        }

        CleanupEngine();
        completion?.TrySetResult(finalTranscript);
    }

    private void CleanupEngine()
    {
        var oldEngine = Interlocked.Exchange(ref engine, null);
        if (oldEngine is null)
        {
            return;
        }

        oldEngine.SpeechRecognized -= HandleSpeechRecognized;
        oldEngine.RecognizeCompleted -= HandleRecognizeCompleted;
        oldEngine.Dispose();
    }

    public void Dispose()
    {
        CancelRecording();
        CleanupEngine();
    }
}
