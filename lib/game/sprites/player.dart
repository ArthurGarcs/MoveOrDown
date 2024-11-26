import 'dart:async';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/geometry.dart';
import 'package:flutter/services.dart';

import '../doodle_dash.dart';
import 'sprites.dart';

enum PlayerState {
  left,
  right,
  center,
  rocket,
  nooglerCenter,
  nooglerLeft,
  nooglerRight
}

class Player extends SpriteGroupComponent<PlayerState>
    with HasGameRef<DoodleDash>, KeyboardHandler, CollisionCallbacks {
  Player({
    super.position,
    required this.character,
    this.jumpSpeed = 600,
  }) : super(
    size: Vector2(79, 109),
    anchor: Anchor.center,
    priority: 1,
  );
  //implementado a gravidade
  int _hAxisInput = 0;
  final int movingLeftInput = -1;
  final int movingRightInput = 1;
  Vector2 _velocity = Vector2.zero();
  bool get isMovingDown => _velocity.y > 0;
  Character character;
  double jumpSpeed;
  final double _gravity = 9;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    await add(CircleHitbox());

    await _loadCharacterSprites();
    current = PlayerState.center;
  }

  //È chamado toda vez que o Estado do componnt é mudado
  //   @overridee
  void update(double dt) {
    //verifica se o estado do jogo esté em Intro e GameOver;
    if (gameRef.gameManager.isIntro || gameRef.gameManager.isGameOver) return;

    _velocity.x = _hAxisInput * jumpSpeed;

    final double dashHorizontalCenter = size.x / 2;

    _velocity.y += _gravity;

    if (position.x < dashHorizontalCenter) {
      position.x = gameRef.size.x - (dashHorizontalCenter);
    }
    if (position.x > gameRef.size.x - (dashHorizontalCenter)) {
      position.x = dashHorizontalCenter;
    }
    //Se o estado for jogável, a posição da Dash será calculada
    // usando a equação
    position += _velocity * dt;
    super.update(dt);
  }

  //metodochamado toda a vez que é detectado a entrada
  //do usario
  // exemplo: uma tecla para esquerda
  //mudando a direção de nosso player
  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    _hAxisInput = 0;

    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft)) {
      moveLeft();
    }

    if (keysPressed.contains(LogicalKeyboardKey.arrowRight)) {
      moveRight();
    }

    //if (keysPressed.contains(LogicalKeyboardKey.arrowUp)) {
    // jump();
    //}

    return true;
  }

  void moveLeft() {
    _hAxisInput = 0;
    if (isWearingHat) {
      current = PlayerState.nooglerLeft;
    } else if (!hasPowerup) {
      current = PlayerState.left;
    }
    _hAxisInput += movingLeftInput;
  }

  void moveRight() {
    _hAxisInput = 0;
    if (isWearingHat) {
      current = PlayerState.nooglerRight;
    } else if (!hasPowerup) {
      current = PlayerState.right;
    }
    _hAxisInput += movingRightInput;
  }

  void resetDirection() {
    _hAxisInput = 0;
  }

  bool get hasPowerup =>
      current == PlayerState.rocket ||
          current == PlayerState.nooglerLeft ||
          current == PlayerState.nooglerRight ||
          current == PlayerState.nooglerCenter;

  bool get isInvincible => current == PlayerState.rocket;

  bool get isWearingHat =>
      current == PlayerState.nooglerLeft ||
          current == PlayerState.nooglerRight ||
          current == PlayerState.nooglerCenter;


  //metodo que detecta colissao do player com as plataformas ou
  //as plataformas eliminatorias
  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    if (other is EnemyPlatform && !isInvincible) {
      gameRef.onLose();
      return;
    }

    //Esse callback chama o método jump da Dash sempre
    // que ela cai em cima de uma NormalPlatform (plataforma normal).
    // A instrução isMovingDown && isCollidingVertically faz com que a
    // Dash se mova para cima pelas plataformas sem acionar um salto.
    bool isCollidingVertically = (intersectionPoints.first.y - intersectionPoints.last.y).abs() < 5;

    //implementei na função oncolission para
    // reconhecer uma colisão com um Springboard ou uma
    // BrokenPlatform. Uma SpringBoard chama jump com um multiplicador
    // de velocidade de 2x e a BrokenPlatform só chama jump caso o
    // estado seja .cracked (trincada), em vez de .broken (quebrada após um salto):
    if (isMovingDown && isCollidingVertically) {
      current = PlayerState.center;
      if (other is NormalPlatform) {
        jump();
        return;
      }else if (other is SpringBoard) {
        jump(specialJumpSpeed: jumpSpeed * 2);
        return;
      } else if (other is BrokenPlatform &&
          other.current == BrokenPlatformState.cracked) {
        jump();
        other.breakPlatform();
        return;
      }
    }

    //Adicione os getters booleanos abaixo à classe Player.
    // Se a Dash tiver um poder ativo, ela poderá ser representada por
    // vários estados diferentes. Esses getters facilitam verificar qual poder está ativo.
    //tambem verifica se a dash ja tem um poder, ela só vai pegar um poder caso nao tenha um
    if (!hasPowerup && other is Rocket) {
      current = PlayerState.rocket;
      other.removeFromParent();
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    } else if (!hasPowerup && other is NooglerHat) {
      if (current == PlayerState.center) current = PlayerState.nooglerCenter;
      if (current == PlayerState.left) current = PlayerState.nooglerLeft;
      if (current == PlayerState.right) current = PlayerState.nooglerRight;
      other.removeFromParent();
      _removePowerupAfterTime(other.activeLengthInMS);
      jump(specialJumpSpeed: jumpSpeed * other.jumpSpeedMultiplier);
      return;
    }
  }

  //método que implementa salto da Dash.
  void jump({double? specialJumpSpeed}) {
    _velocity.y = specialJumpSpeed != null ? -specialJumpSpeed : -jumpSpeed;
  }

  void _removePowerupAfterTime(int ms) {
    Future.delayed(Duration(milliseconds: ms), () {
      current = PlayerState.center;
    });
  }

  void setJumpSpeed(double newJumpSpeed) {
    jumpSpeed = newJumpSpeed;
  }

  void reset() {
    _velocity = Vector2.zero();
    current = PlayerState.center;
  }

  void resetPosition() {
    position = Vector2(
      (gameRef.size.x - size.x) / 2,
      (gameRef.size.y - size.y) / 2,
    );
  }


  // O codigo a baixo:
  // funciona com a troca de estado, se o sprite estiver com o
  // estado como  left (direita) é carregado com sua
  // imagem voltado para a direita, e assim vai seguir para
  // esquerda e centro (tela).
  Future<void> _loadCharacterSprites() async {

    final left = await gameRef.loadSprite('game/${character.name}_left.png');
    final right = await gameRef.loadSprite('game/${character.name}_right.png');
    final center =
    await gameRef.loadSprite('game/${character.name}_center.png');
    final rocket = await gameRef.loadSprite('game/rocket_4.png');
    final nooglerCenter =
    await gameRef.loadSprite('game/${character.name}_hat_center.png');
    final nooglerLeft =
    await gameRef.loadSprite('game/${character.name}_hat_left.png');
    final nooglerRight =
    await gameRef.loadSprite('game/${character.name}_hat_right.png');

    sprites = <PlayerState, Sprite>{
      PlayerState.left: left,
      PlayerState.right: right,
      PlayerState.center: center,
      PlayerState.rocket: rocket,
      PlayerState.nooglerCenter: nooglerCenter,
      PlayerState.nooglerLeft: nooglerLeft,
      PlayerState.nooglerRight: nooglerRight,
    };
  }
}
