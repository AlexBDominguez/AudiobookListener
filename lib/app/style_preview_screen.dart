import 'package:flutter/material.dart';

import '../core/duration_format.dart';
import 'theme/app_theme.dart';

/// Temporary screen to validate the visual style (Phase 0) before building
/// the real screens. All values are fake.
class StylePreviewScreen extends StatelessWidget {
  const StylePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Muestra de estilo')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screen),
        children: [
          Text('Biblioteca', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Expanded(
                child: _BookCard(
                  title: 'El nombre del viento',
                  author: 'Patrick Rothfuss',
                  progress: 0.42,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: _BookCard(
                  title: 'Dune',
                  author: 'Frank Herbert',
                  progress: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text('Reproductor', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          const _PlayerPreview(),
          const SizedBox(height: AppSpacing.xxl),
          Text('Botones', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.folder_open_rounded),
                label: const Text('Elegir carpeta de audiolibros'),
              ),
              OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
              TextButton(onPressed: () {}, child: const Text('Ajustes')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final speed in ['1.0x', '1.25x', '1.5x', '2.0x'])
                ChoiceChip(
                  label: Text(speed),
                  selected: speed == '1.25x',
                  onSelected: (_) {},
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookCard extends StatelessWidget {
  const _BookCard({
    required this.title,
    required this.author,
    required this.progress,
  });

  final String title;
  final String author;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(aspectRatio: 1, child: _InitialsCover(title: title)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                style: context.text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                author,
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      ),
    );
  }
}

/// Placeholder cover with the title's initials.
class _InitialsCover extends StatelessWidget {
  const _InitialsCover({required this.title});

  final String title;

  String get _initials => title
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty && w[0].toUpperCase() != w[0].toLowerCase())
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.coverAll,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.primary, c.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: context.text.headlineMedium?.copyWith(color: c.onPrimary),
        ),
      ),
    );
  }
}

class _PlayerPreview extends StatefulWidget {
  const _PlayerPreview();

  @override
  State<_PlayerPreview> createState() => _PlayerPreviewState();
}

class _PlayerPreviewState extends State<_PlayerPreview> {
  static const _chapterLength = Duration(minutes: 23, seconds: 41);
  double _position = 0.35;
  bool _playing = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final elapsed = _chapterLength * _position;
    final remaining = elapsed - _chapterLength;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardAll,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [c.primary.withValues(alpha: 0.35), c.surface],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text('Capítulo 4 de 23', style: context.text.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            Text('La universidad', style: context.text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Slider(
              value: _position,
              onChanged: (v) => setState(() => _position = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(elapsed),
                    style: AppTextStyles.timecode(c),
                  ),
                  Text(
                    formatDuration(remaining),
                    style: AppTextStyles.timecode(c),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  tooltip: 'Capítulo anterior',
                  onPressed: () {},
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                IconButton(
                  tooltip: 'Retroceder 15 segundos',
                  onPressed: () {},
                  icon: const Icon(Icons.replay_rounded),
                ),
                _PlayPauseButton(
                  playing: _playing,
                  onPressed: () => setState(() => _playing = !_playing),
                ),
                IconButton(
                  tooltip: 'Avanzar 30 segundos',
                  onPressed: () {},
                  icon: const Icon(Icons.forward_30_rounded),
                ),
                IconButton(
                  tooltip: 'Capítulo siguiente',
                  onPressed: () {},
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.playing, required this.onPressed});

  static const double _size = 64;

  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: playing ? 'Pausar' : 'Reproducir',
      excludeSemantics: true,
      child: Material(
        color: c.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox.square(
            dimension: _size,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(playing),
                color: c.onPrimary,
                size: _size / 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
