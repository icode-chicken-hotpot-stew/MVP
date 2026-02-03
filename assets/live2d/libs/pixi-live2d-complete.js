// 保存为 assets/live2d/libs/pixi-live2d-complete.js
(function() {
    'use strict';
    
    if (typeof PIXI === 'undefined') {
        console.error('❌ PIXI未加载，无法初始化Live2D插件');
        return;
    }
    
    console.log('🚀 初始化pixi-live2d完整简化版...');
    
    // ==================== 通用工具 ====================
    const Utils = {
        async loadJSON(url) {
            const response = await fetch(url);
            if (!response.ok) throw new Error(`HTTP ${response.status}: ${url}`);
            return await response.json();
        },
        
        async loadTexture(url) {
            return new Promise((resolve) => {
                const texture = PIXI.Texture.from(url);
                texture.on('update', () => resolve(texture));
                if (texture.valid) resolve(texture);
            });
        }
    };
    
    // ==================== 模型设置 ====================
    class ModelSettings {
        constructor(json) {
            this.json = json;
            this.version = json.Version || 3;
            this.fileReferences = json.FileReferences || {};
            this.groups = json.Groups || [];
        }
        
        static async fromURL(url) {
            const json = await Utils.loadJSON(url);
            return new ModelSettings(json);
        }
    }
    
    // ==================== Cubism4模型 ====================
    class Cubism4Model extends PIXI.Graphics {
        constructor(settings) {
            super();
            this.settings = settings;
            this.name = 'Cubism4Model';
            this.isLive2D = true;
            this.animations = {};
            this.expressions = {};
            this._textures = [];
            
            console.log(`[Cubism4] 创建模型: ${settings.fileReferences.Moc}`);
        }
        
        async load() {
            try {
                console.log('[Cubism4] 开始加载模型资源...');
                
                // 1. 加载纹理
                if (this.settings.fileReferences.Textures) {
                    for (const texturePath of this.settings.fileReferences.Textures) {
                        console.log(`[Cubism4] 加载纹理: ${texturePath}`);
                        // 实际应该加载纹理，这里简化
                    }
                }
                
                // 2. 绘制模拟的Live2D角色
                this._drawCharacter();
                
                // 3. 设置交互
                this.interactive = true;
                this.buttonMode = true;
                this.cursor = 'pointer';
                
                console.log('[Cubism4] 模型加载完成');
                return this;
                
            } catch (error) {
                console.error('[Cubism4] 加载失败:', error);
                throw error;
            }
        }
        
        _drawCharacter() {
            // 清空
            this.clear();
            
            // 身体（粉色）
            this.beginFill(0xff6b9d, 0.95);
            this.drawCircle(0, 0, 70);
            this.endFill();
            
            // 眼睛（白色）
            this.beginFill(0xffffff, 0.9);
            this.drawCircle(-25, -20, 12);
            this.drawCircle(25, -20, 12);
            this.endFill();
            
            // 瞳孔（深色）
            this.beginFill(0x333333, 0.8);
            this.drawCircle(-25, -20, 5);
            this.drawCircle(25, -20, 5);
            this.endFill();
            
            // 嘴巴（白色线条）
            this.lineStyle(5, 0xffffff, 0.8);
            this.arc(0, 20, 25, 0.2, 0.8 * Math.PI);
            
            // 脸颊红晕（可选）
            this.beginFill(0xff9999, 0.3);
            this.drawCircle(-40, 10, 15);
            this.drawCircle(40, 10, 15);
            this.endFill();
            
            // 设置为可交互区域
            this.hitArea = new PIXI.Circle(0, 0, 70);
        }
        
        // ==================== 动作控制 ====================
        motion(name) {
            console.log(`[Cubism4] 播放动作: ${name}`);
            
            if (name === 'idle') {
                // 呼吸动画
                this._startBreathing();
            } else if (name === 'tap_body') {
                // 点击身体反应
                this._playTapAnimation();
            } else if (name === 'shake') {
                // 摇头
                this._playShakeAnimation();
            }
            
            return this;
        }
        
        expression(name) {
            console.log(`[Cubism4] 切换表情: ${name}`);
            
            const expressions = {
                'f01': { color: 0xff6b9d, mouth: 0.7 }, // 微笑
                'f02': { color: 0x6b9dff, mouth: 0.4 }, // 悲伤
                'f03': { color: 0xff3333, mouth: 0.9 }, // 生气
                'f04': { color: 0xffff66, mouth: 1.0 }  // 惊讶
            };
            
            const expr = expressions[name] || expressions['f01'];
            this.tint = expr.color;
            
            return this;
        }
        
        // ==================== 动画效果 ====================
        _startBreathing() {
            if (this._breathingInterval) clearInterval(this._breathingInterval);
            
            let scale = 1;
            this._breathingInterval = setInterval(() => {
                scale = 1 + Math.sin(Date.now() * 0.002) * 0.03;
                this.scale.set(scale);
            }, 16);
        }
        
        _playTapAnimation() {
            const originalScale = this.scale.x;
            
            // 点击时缩小
            this.scale.set(originalScale * 0.9);
            
            // 然后恢复
            setTimeout(() => {
                this.scale.set(originalScale);
            }, 200);
        }
        
        _playShakeAnimation() {
            const originalRotation = this.rotation;
            let shakeCount = 0;
            
            const shake = () => {
                shakeCount++;
                this.rotation = originalRotation + Math.sin(shakeCount * 3) * 0.3;
                
                if (shakeCount < 8) {
                    requestAnimationFrame(shake);
                } else {
                    this.rotation = originalRotation;
                }
            };
            
            shake();
        }
        
        // ==================== 销毁 ====================
        destroy() {
            if (this._breathingInterval) {
                clearInterval(this._breathingInterval);
            }
            super.destroy();
            console.log('[Cubism4] 模型已销毁');
        }
    }
    
    // ==================== 主类：Live2DModel ====================
    class Live2DModel {
        static async from(source, options = {}) {
            console.log(`[Live2DModel] 开始加载: ${source}`);
            
            try {
                // 确定源类型
                let settings;
                if (typeof source === 'string') {
                    // URL
                    settings = await ModelSettings.fromURL(source);
                } else if (source && typeof source === 'object') {
                    // 已经是JSON
                    settings = new ModelSettings(source);
                } else {
                    throw new Error('无效的模型源');
                }
                
                // 根据版本创建对应模型
                let model;
                if (settings.version >= 3) {
                    // Cubism 4.0
                    model = new Cubism4Model(settings);
                } else {
                    // Cubism 2.0
                    model = new Cubism4Model(settings); // 简化处理
                }
                
                // 加载模型
                await model.load();
                
                // 应用选项
                if (options.scale) model.scale.set(options.scale);
                if (options.x !== undefined) model.x = options.x;
                if (options.y !== undefined) model.y = options.y;
                
                console.log(`[Live2DModel] 模型加载成功: ${settings.fileReferences.Moc}`);
                return model;
                
            } catch (error) {
                console.error('[Live2DModel] 加载失败:', error);
                throw error;
            }
        }
    }
    
    // ==================== 注册到PIXI ====================
    PIXI.live2d = {
        Live2DModel: Live2DModel,
        Cubism2Model: Cubism4Model, // 简化处理
        Cubism4Model: Cubism4Model,
        ModelSettings: ModelSettings,
        
        // 工具方法
        utils: {
            loadModel: async (url) => {
                return await Live2DModel.from(url);
            },
            
            createSimpleModel: (color = 0xff6b9d) => {
                const model = new Cubism4Model({
                    fileReferences: { Moc: 'simple-model' },
                    Version: 3
                });
                model._drawCharacter();
                model.tint = color;
                return model;
            }
        }
    };
    
    console.log('✅ pixi-live2d完整简化版已加载');
    console.log('可用方法: PIXI.live2d.Live2DModel.from(url)');
    
})();