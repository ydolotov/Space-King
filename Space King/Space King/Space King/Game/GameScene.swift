//
//  GameScene.swift
//  Space King
//
//  Created by Yura Dolotov on 05/11/2018.
//  Copyright © 2018 Yura Dolotov. All rights reserved.
//

import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var background: SKEmitterNode!
    var player: SKSpriteNode!
    var gameTimer: Timer!
    var possibleAliens = ["alien", "alien2", "alien3"]
    var scoreLabel: SKLabelNode!
    var score: Int = 0 {
        didSet{
            scoreLabel.text = "Score: \(score)"
        }
    }
    let  alienCategory: UInt32 = 0x1 << 1
    let photonTorpedoCategory: UInt32 = 0x1 << 0
    let motionManager = CMMotionManager()
    var xAccerleration: CGFloat = 0
    
    var liveArray: [SKSpriteNode]!
    
    override func didMove(to view: SKView) {
        //ADDING LIVES ON THE SCREEN
        addLives()
    
        //SET UP OUR BACKGROUND
        background = SKEmitterNode (fileNamed: "Starfield")
        background.position = CGPoint (x: 0, y: 1472)
        background.advanceSimulationTime(10) //START OUR BACKGROUND AT 10 SECONDS ANIMATION
        self.addChild(background)
        background.zPosition = -1 //BG BEHIND OTHER OBJECTS
        
        //ADD PLAYER
        player = SKSpriteNode(imageNamed: "shuttle")
        player.position = CGPoint(x: self.frame.size.width/2, y: player.size.height/2 + 20) //POSITIOPN FOR PLAYER
        self.addChild(player)
        
        //ADDING SOME PROPERTIES TO PHYSICS WORLD
        self.physicsWorld.gravity = CGVector (dx: 0, dy: 0)
        self.physicsWorld.contactDelegate = self
        
        //SCORE LABEL
        scoreLabel = SKLabelNode (text: "Score: 0")
        scoreLabel.position = CGPoint (x: 80, y: self.frame.size.height - 70)
        scoreLabel.fontSize = 28
        scoreLabel.fontName = "AvenirNext-Bold"
        scoreLabel.fontColor = UIColor.white
        score = 0 // UPDATE SCORE
        self.addChild(scoreLabel)
        
        //DIFFICULTY SELECTION
        var timeInterval = 0.75
        
        if UserDefaults.standard.bool(forKey: "Hard") {
            timeInterval = 0.3
        }
        
        //ADD ENEMIES AND TIMER
        gameTimer = Timer.scheduledTimer(timeInterval: timeInterval, target: self, selector: #selector (addAlien), userInfo: nil, repeats: true)
        
        //ACCELERATION SHUTTLE MOVEMENT
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { (data:CMAccelerometerData?, error:Error?) in
            if let accelerometerData = data {
                let acceleration = accelerometerData.acceleration
                self.xAccerleration = CGFloat(acceleration.x) * 0.75 + self.xAccerleration * 0.25
            }
        }
    }
    
    @objc func addAlien () {
        possibleAliens = GKRandomSource.sharedRandom().arrayByShufflingObjects(in: possibleAliens) as! [String]
        let alien = SKSpriteNode (imageNamed: possibleAliens[0])
        let randomAlienPosition = GKRandomDistribution (lowestValue: 0, highestValue: 414)
        let position = CGFloat (randomAlienPosition.nextInt())
        alien.position = CGPoint (x: position, y: self.frame.size.height + alien.size.height)
        //USE PHYSICS
        alien.physicsBody = SKPhysicsBody (rectangleOf: alien.size)
        alien.physicsBody?.isDynamic = true
        
        //INTERACTION WITH OUR WEAPON
        alien.physicsBody?.categoryBitMask = alienCategory
        alien.physicsBody?.contactTestBitMask = photonTorpedoCategory
        alien.physicsBody?.collisionBitMask = 0
        self.addChild(alien)
        //MAKES ALIENS MOVE
        let animationDuration:TimeInterval = 5
        var actionArray = [SKAction]()
        actionArray.append(SKAction.move(to: CGPoint(x: position, y: -alien.size.height), duration: animationDuration))
        //LIVES OPERATION
        actionArray.append(SKAction.run {
            self.run(SKAction.playSoundFileNamed("lose.mp3", waitForCompletion: false))
            
            if self.liveArray.count > 0 {
                let liveNode = self.liveArray.first
                liveNode!.removeFromParent()
                self.liveArray.removeFirst()
                
                if self.liveArray.count == 0 {
                    //GAME OVER SCREEN TRANSITION
                    let transition = SKTransition.flipHorizontal(withDuration: 0.5)
                    let gameOver = SKScene(fileNamed: "menuScene") as! menuScene
                    //gameOver.score = self.score
                    self.view?.presentScene(gameOver, transition: transition)
                }
            }
            
        })
        
        actionArray.append(SKAction.removeFromParent())
        alien.run(SKAction.sequence(actionArray))
    }
    
    //FIRE TORPEDO FUNCTION
    func fireTorpedo() {
        self.run(SKAction.playSoundFileNamed("torpedo.mp3", waitForCompletion: false))
        
        let torpedoNode = SKSpriteNode(imageNamed: "torpedo")
        torpedoNode.position = player.position
        torpedoNode.position.y += 5
        
        torpedoNode.physicsBody = SKPhysicsBody(circleOfRadius: torpedoNode.size.width / 2)
        torpedoNode.physicsBody?.isDynamic = true
        
        torpedoNode.physicsBody?.categoryBitMask = photonTorpedoCategory
        torpedoNode.physicsBody?.contactTestBitMask = alienCategory
        torpedoNode.physicsBody?.collisionBitMask = 0
        torpedoNode.physicsBody?.usesPreciseCollisionDetection = true
        
        self.addChild(torpedoNode)
        let animationDuration:TimeInterval = 0.3
        var actionArray = [SKAction]()
        
        actionArray.append(SKAction.move(to: CGPoint(x: player.position.x, y: self.frame.size.height + 10), duration: animationDuration))
        actionArray.append(SKAction.removeFromParent())
        torpedoNode.run(SKAction.sequence(actionArray))
    }
    
    //KILLING ALIENS WITH OUR GUN AND EXPLOSION
    func didBegin(_ contact: SKPhysicsContact) {
        var fisrtBody:SKPhysicsBody
        var secondBody:SKPhysicsBody
        
        if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
            fisrtBody = contact.bodyA
            secondBody = contact.bodyB
        } else {
            fisrtBody = contact.bodyB
            secondBody = contact.bodyA
        }
        
        if (fisrtBody.categoryBitMask & photonTorpedoCategory) != 0 && (secondBody.categoryBitMask & alienCategory) != 0 {
            torpedoDidCollisionWithAlien(torpedoNode: fisrtBody.node as! SKSpriteNode, alienNode: secondBody.node as! SKSpriteNode)
        }
    }
    
    func torpedoDidCollisionWithAlien (torpedoNode: SKSpriteNode, alienNode: SKSpriteNode) {
        let explosion = SKEmitterNode(fileNamed: "Explosion")!
        explosion.position = alienNode.position
        self.addChild(explosion)
        
        self.run(SKAction.playSoundFileNamed("explosion.mp3", waitForCompletion: false))
        torpedoNode.removeFromParent()
        alienNode.removeFromParent()
        
        self.run(SKAction.wait(forDuration: 2)) {
            explosion.removeFromParent()
        }
        score += 5
    }
    
    override func didSimulatePhysics() {
        
        player.position.x += xAccerleration * 50
        //player.position.y += xAccerleration * 50
        
        if player.position.x < -20 {
            player.position = CGPoint(x: self.size.width + 20, y: player.position.y)
        } else if player.position.x > self.size.width + 20 {
            player.position = CGPoint(x: -20, y: player.position.y)
        }
    }
    
    //ADDING LIVES ON THE SCREEN
    func addLives () {
        liveArray = [SKSpriteNode]()
        
        for live in 1 ... 3 {
            let liveNode = SKSpriteNode(imageNamed: "shuttle")
            liveNode.position = CGPoint(x: self.frame.size.width - CGFloat(4 - live)*liveNode.size.width, y: self.frame.size.height - 60)
            self.addChild(liveNode)
            liveArray.append(liveNode)
        }
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        fireTorpedo()
    }
    
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
    }
}
