# chapter2_ep07.gd - 第二章第7话
extends Node2D

@onready var novel_interface = $NovelInterface

func _ready():
	await get_tree().process_frame
	chapter2_ep07_script()

func play_script():
	pass

func chapter2_ep07_script():
	novel_interface.change_music("res://assets/audio/music/Like A Girl.mp3")
	novel_interface.change_background("res://assets/images/bg/other/BG_City_street2.png")
	novel_interface.show_character("ren_battle","gratified")
	await novel_interface.show_dialog("刚才真是好险……\n总算回来了~~", GameConfig.player_name)
	novel_interface.character_move_left(-0.25)
	novel_interface.show_2nd_character("anne_battle","perspire",0.25)
	await novel_interface.show_dialog(GameConfig.player_name+"，你受伤了？\n手臂流了好多血！", "安妮")
	novel_interface.character_light(0.35,"happy")
	novel_interface.character_2nd_dark()
	await novel_interface.show_dialog("没关系，只是擦伤而已\n这点伤对男生来说算不了什么！", GameConfig.player_name)
	novel_interface.change_expression("worry")
	await novel_interface.show_dialog("但现在明明就是女生嘛，不要太逞强啦！\n而且你的脚也扭伤了吧……", "安妮")
	novel_interface.character_light(0.35,"serious")
	novel_interface.character_2nd_dark()
	await novel_interface.show_dialog("嗯……看来事情并不简单，如果不能把麻烦都解决\n掉，说不定还会有很多人受伤……", GameConfig.player_name)
	novel_interface.character_dark()
	novel_interface.character_2nd_light()
	await novel_interface.show_dialog("拜托你多爱惜下自己好不好嘛！\n手臂还在流血呢。", "安妮")
	await novel_interface.hide_2nd_character()
	novel_interface.character_move_right(0,0.3,true,"happy")
	await novel_interface.show_dialog("我会的。谢谢你，安妮～", GameConfig.player_name)
	novel_interface.change_expression("gratified")
	await novel_interface.show_dialog("不过……还是没什么线索啊……\n要不我们继续去下一个区域吧？", GameConfig.player_name)
	await novel_interface.hide_character()
	novel_interface.show_character("liliu_uniform2","serious")
	await novel_interface.show_dialog("（突然出现在面前）你这小丫头……", "莉琉")
	await novel_interface.hide_character()
	novel_interface.show_character("ren_battle","panic")
	await novel_interface.show_dialog("莉琉博士，啊不，长官！\n你是在等我们吗？", GameConfig.player_name)
	novel_interface.change_expression("happy")
	await novel_interface.show_dialog("我们正准备去下个区域探查…", GameConfig.player_name)
	await novel_interface.hide_character()
	novel_interface.show_character("liliu_uniform2","speak")
	await novel_interface.show_dialog("等一下，你……是不是刚刚战斗过？！", "莉琉")
	novel_interface.character_move_left(-0.25)
	novel_interface.show_2nd_character("ren_battle","perspire1",0.25)
	await novel_interface.show_dialog("呃，我也…只是勉力试试…", GameConfig.player_name)
	novel_interface.character_light(0.35,"speak")
	novel_interface.character_2nd_dark()
	await novel_interface.show_dialog("我可记得跟你说过，不可以勉强自己的吧！！", "莉琉")
	novel_interface.change_expression("serious")
	await novel_interface.show_dialog("如果出了不可控的危险，对我可是莫大的损失！\n看看，现在就已经受伤了吧！", "莉琉")
	await novel_interface.hide_2nd_character()
	novel_interface.character_move_right(0,0.3,false,"speak")
	await novel_interface.show_dialog("医疗组！ 有人受伤，给她处理下，马上带回总\n部！", "莉琉")
	await novel_interface.hide_character()
	novel_interface.show_character("anne_battle","normal")
	await novel_interface.show_dialog(GameConfig.player_name+"，莉琉长官好像很担心你呢……\n我们要不就……？", "安妮")
	novel_interface.character_move_left(-0.25)
	novel_interface.show_2nd_character("ren_battle","upset",0.25)
	await novel_interface.show_dialog("……嗯", GameConfig.player_name)
	await novel_interface.hide_all_characters()
	await novel_interface.show_text_only("一丝难以言说的慌乱悄悄爬上了心间。")

	print("=== 第二章第7话结束 ===")

	# 调用剧情结束函数
	await novel_interface.end_story_episode(0.5)
