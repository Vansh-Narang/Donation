import 'package:flutter/cupertino.dart';

enum ImageViewState {
  imageIdle,
  imageLoading
}

enum ImageOnTapAvailability{
  yes,no
}
class ChatScreenProvider extends ChangeNotifier{
  ImageViewState _imageViewState = ImageViewState.imageIdle;
  ImageOnTapAvailability imageOnTapAvailability = ImageOnTapAvailability.no;

  ImageViewState get imageViewState => _imageViewState;

  void setToLoading(){
    _imageViewState = ImageViewState.imageLoading;
    notifyListeners();
  }

  void setToIdle(){
    _imageViewState = ImageViewState.imageIdle;
    notifyListeners();
  }


}