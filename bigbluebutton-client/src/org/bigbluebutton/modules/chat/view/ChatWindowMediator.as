/**
* BigBlueButton open source conferencing system - http://www.bigbluebutton.org/
*
* Copyright (c) 2008 by respective authors (see below).
*
* This program is free software; you can redistribute it and/or modify it under the
* terms of the GNU Lesser General Public License as published by the Free Software
* Foundation; either version 2.1 of the License, or (at your option) any later
* version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT ANY
* WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
* PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
*
* You should have received a copy of the GNU Lesser General Public License along
* with this program; if not, write to the Free Software Foundation, Inc.,
* 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
* 
*/
package org.bigbluebutton.modules.chat.view
{
	import flash.events.Event;
	
	import mx.controls.Alert;
	import mx.core.Container;
	
	import org.bigbluebutton.modules.chat.ChatModuleConstants;
	import org.bigbluebutton.modules.chat.model.MessageVO;
	import org.bigbluebutton.modules.chat.model.business.ChatProxy;
	import org.bigbluebutton.modules.chat.model.business.PrivateProxy;
	import org.bigbluebutton.modules.chat.model.business.UserVO;
	import org.bigbluebutton.modules.chat.view.components.ChatBox;
	import org.bigbluebutton.modules.chat.view.components.ChatWindow;
	import org.puremvc.as3.multicore.interfaces.IMediator;
	import org.puremvc.as3.multicore.interfaces.INotification;
	import org.puremvc.as3.multicore.patterns.mediator.Mediator;

	
	public class ChatWindowMediator extends Mediator implements IMediator
	{
		public static const NAME:String = "ChatMediator";
		public static const NEW_MESSAGE:String = "newMessage";
		
		private var _module:ChatModule;
		private var _chatWindow:ChatWindow;
		private var _chatWindowOpen:Boolean = false;
		
		public function ChatWindowMediator(module:ChatModule)
		{
			super(NAME, module);
			_module = module;
			_chatWindow = new ChatWindow();
			_chatWindow.name = _module.username;
			_chatWindow.addEventListener(ChatWindow.SEND_MESSAGE, onSendChatMessage);
			_chatWindow.addEventListener(ChatModuleConstants.OPEN_CHAT_BOX, onOpenChatBox);
		}

        private function time() : String
		{
			var date:Date = new Date();
			var t:String = date.toLocaleTimeString();
			return t;
		}		

		public function onSendChatMessage(e:Event):void
		{
			var newMessage:String;			
			newMessage = "<font color=\"#" + _chatWindow.cmpColorPicker.selectedColor.toString(16) + "\"><b>[" + 
					_module.username +" - "+ time()+ "]</b> " + _chatWindow.txtMsg.text + "</font><br/>";
			
			if (_chatWindow.tabNav.selectedChild.id == "Public") proxy.sendMessage(newMessage);
			else{
				var privateMessage:MessageVO = new MessageVO(newMessage, String(_module.userid), _chatWindow.tabNav.selectedChild.name);
				privateProxy.sendMessage(privateMessage);
				(_chatWindow.tabNav.selectedChild as ChatBox).showNewMessage(newMessage);
			}
			_chatWindow.txtMsg.text = "";
		}
		
		public function onOpenChatBox(e:Event):void{
			var name:String = _chatWindow.participantList.selectedItem.userid;
			
			if (_chatWindow.tabNav.getChildByName(name) != null){
				_chatWindow.tabNav.selectedChild = _chatWindow.tabNav.getChildByName(name) as Container;
				return;
			}
			
			var chatBox:ChatBox = new ChatBox();
			chatBox.id = _chatWindow.participantList.selectedItem.label;
			chatBox.name = name;
			sendNotification(ChatModuleConstants.OPEN_CHAT_BOX, chatBox);
			
			_chatWindow.tabNav.selectedChild = chatBox;
			//chatBox.boxButton = _chatWindow.tabNav.getTabAt(_chatWindow.tabNav.getChildIndex(_chatWindow.tabNav.getChildByName(name)));
		}
			
		override public function listNotificationInterests():Array
		{
			return [
					ChatModuleConstants.NEW_MESSAGE,
					ChatModuleConstants.CLOSE_WINDOW,
					ChatModuleConstants.OPEN_WINDOW,
					ChatModuleConstants.ADD_PARTICIPANT,
					ChatModuleConstants.OPEN_CHAT_BOX,
					ChatModuleConstants.REMOVE_PARTICIPANT,
					ChatModuleConstants.NEW_PRIVATE_MESSAGE
				   ];
		}
						
		/**
		 * Handlers for notification(s) this class is listening to 
		 * @param notification
		 * 
		 */		
		override public function handleNotification(notification:INotification):void
		{
			switch(notification.getName())
			{
				case ChatModuleConstants.NEW_MESSAGE:
					var publicChat:ChatBox = _chatWindow.tabNav.getChildByName("0") as ChatBox;
					publicChat.showNewMessage(notification.getBody() as String);
					break;	
				case ChatModuleConstants.CLOSE_WINDOW:
					if (_chatWindowOpen) {
						facade.sendNotification(ChatModuleConstants.REMOVE_WINDOW, _chatWindow);
						_chatWindowOpen = false;
					}
					break;					
				case ChatModuleConstants.OPEN_WINDOW:
		   			_chatWindow.title = "Group Chat";
		   			_chatWindow.showCloseButton = false;
		   			_chatWindow.xPosition = 675;
		   			_chatWindow.yPosition = 0;
		   			facade.sendNotification(ChatModuleConstants.ADD_WINDOW, _chatWindow); 
		   			_chatWindowOpen = true;
					break;
				case ChatModuleConstants.ADD_PARTICIPANT:
					var newUser:UserVO = notification.getBody() as UserVO
					if (newUser.userid != String(_module.userid)) _chatWindow.addParticipant(newUser);
					break;
				case ChatModuleConstants.OPEN_CHAT_BOX:
					_chatWindow.tabNav.addChild(notification.getBody() as ChatBox);
					break;
				case ChatModuleConstants.REMOVE_PARTICIPANT:
					_chatWindow.removeParticipant(notification.getBody() as String);
					break;
				case ChatModuleConstants.NEW_PRIVATE_MESSAGE:
					showPrivateMessage(notification.getBody() as MessageVO);
					break;
			}
		}
			
		public function get proxy():ChatProxy
		{
			return facade.retrieveProxy(ChatProxy.NAME) as ChatProxy;
		}
		
		public function get privateProxy():PrivateProxy{
			return facade.retrieveProxy(PrivateProxy.NAME) as PrivateProxy;
		}
		
		public function showPrivateMessage(message:MessageVO):void{
			var participantName:String = _chatWindow.getParticipantName(message.sender);
			
			var privateBox:ChatBoxMediator = facade.retrieveMediator(message.sender) as ChatBoxMediator;
			if (privateBox == null) {
				var chatBox:ChatBox = new ChatBox();
				chatBox.id = participantName;
				chatBox.name = message.sender;
				sendNotification(ChatModuleConstants.OPEN_CHAT_BOX, chatBox);
				chatBox.boxButton = _chatWindow.tabNav.getTabAt(_chatWindow.tabNav.numChildren-1);
				privateBox = facade.retrieveMediator(message.sender) as ChatBoxMediator;
			}
			if (_chatWindow.tabNav.selectedChild.name != message.sender) _chatWindow.setMessageUnread(message.sender);
			privateBox.showMessage(message.message);
		}
	}
}