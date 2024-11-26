import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

import './world.dart';
import 'managers/managers.dart';
import 'sprites/sprites.dart';

enum Character { dash, sparky }

//instanciamento da classe player.
class DoodleDash extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  DoodleDash({super.children});
  //Implementado logica de colissao nativa do flame no HasCollisionDetection.

  final World _world = World();
  LevelManager levelManager = LevelManager();
  GameManager gameManager = GameManager();
  int screenBufferSpace = 300;
  ObjectManager objectManager = ObjectManager();

  late Player player;

  @override
  Future<void> onLoad() async {
    await add(_world);

    await add(gameManager);

    overlays.add('gameOverlay');

    await add(levelManager);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (gameManager.isGameOver) {
      return;
    }

    if (gameManager.isIntro) {
      overlays.add('mainMenuOverlay');
      return;
    }

    if (gameManager.isPlaying) {

      checkLevelUp();

      //Implementado logica da camere que acompanha o player
      final Rect worldBounds = Rect.fromLTRB(
        0,
        camera.position.y - screenBufferSpace,
        camera.gameSize.x,
        camera.position.y + _world.size.y,
      );
      camera.worldBounds = worldBounds;

      if (player.isMovingDown) {
        camera.worldBounds = worldBounds;
      }

      var isInTopHalfOfScreen = player.position.y <= (_world.size.y / 2);
      if (!player.isMovingDown && isInTopHalfOfScreen) {
        camera.followComponent(player);
      }
    }

    //chama onLose quando o jogador cair pela parte de baixo da tela
    if (player.position.y > camera.position.y + _world.size.y + player.size.y + screenBufferSpace) {
      onLose();
    }
  }

  @override
  Color backgroundColor() {
    return const Color.fromARGB(255, 241, 247, 249);
  }

  //sera chamado ao inicializar o game Start
  //é chamado no método initializeGameStart, cria um ObjectManager
  // que é inicializado, configurado com base no
  // nível de dificuldade e adicionado ao jogo do Flame:
  void initializeGameStart() {
    setCharacter();

    gameManager.reset();
    //reseta a posição do player.

    if (children.contains(objectManager)) objectManager.removeFromParent();

    //reinicia a camera toda vez que é reiniciado o jogo
    levelManager.reset();

    player.reset();
    camera.worldBounds = Rect.fromLTRB(
      0,
      -_world.size.y,
      camera.gameSize.x,
      _world.size.y + screenBufferSpace,
    );
    camera.followComponent(player);

    player.resetPosition();

    objectManager = ObjectManager(
        minVerticalDistanceToNextPlatform: levelManager.minDistance,
        maxVerticalDistanceToNextPlatform: levelManager.maxDistance);

    add(objectManager);

    objectManager.configure(levelManager.level, levelManager.difficulty);
  }

  //seta o jump() baseado no nivel de dificuldade
  void setCharacter() {
    player = Player(
      character: gameManager.character,
      jumpSpeed: levelManager.startingJumpSpeed,
    );
    add(player);
  }

  void startGame() {
    initializeGameStart();
    gameManager.state = GameState.playing;
    overlays.remove('mainMenuOverlay');
  }

  // é chamado sempre que o jogo termina.
  // Ele define o estado do jogo,
  // remove o jogador da tela e ativa o menu/sobreposição **Game Over**
  void onLose() {
    gameManager.state = GameState.gameOver;
    player.removeFromParent();
    overlays.add('gameOverOverlay');
  }

// uma sobreposição pode ser usada em
// qualquer lugar do jogo. Mostre uma sobreposição usando
// overlays.add e oculte-a com overlays.remove
  void resetGame() {
    startGame();
    overlays.remove('gameOverOverlay');
  }

  void togglePauseState() {
    if (paused) {
      resumeEngine();
    } else {
      pauseEngine();
    }
  }

  //chama uma funçaõ da classe objectManager
  // Quando o jogador avança de nível,
  // o ObjectManager reconfigura os parâmetros de geração de plataforma
  // com base no nível de dificuldade.
  void checkLevelUp() {
    if (levelManager.shouldLevelUp(gameManager.score.value)) {
      levelManager.increaseLevel();

      objectManager.configure(levelManager.level, levelManager.difficulty);

      player.setJumpSpeed(levelManager.jumpSpeed);
    }
  }
}
